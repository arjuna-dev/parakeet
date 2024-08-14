import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/file_duration_update_service.dart';
import 'package:parakeet/services/update_firestore_service.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:parakeet/utils/script_generator.dart' as script_generator;
import 'package:parakeet/widgets/position_data.dart';
import 'package:parakeet/widgets/control_buttons.dart';
import 'package:parakeet/widgets/dialogue_list.dart';
import 'package:parakeet/widgets/position_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AudioPlayerScreen extends StatefulWidget {
  final String documentID;
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;

  const AudioPlayerScreen({
    Key? key,
    required this.documentID,
    required this.dialogue,
    required this.userID,
    required this.title,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
    required this.generating,
  }) : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  UpdateFirestoreService? firestoreService;
  FileDurationUpdate? fileDurationUpdate;
  late AudioPlayer player;
  late ConcatenatingAudioSource playlist;
  late AnalyticsManager analyticsManager;

  String currentTrack = '';
  String? previousTargetTrack;
  String? previousTargetPhrase;
  bool isPlaying = false;
  bool isStopped = false;
  bool _isPaused = false;
  int updateNumber = 0;

  Duration totalDuration = Duration.zero;
  Duration finalTotalDuration = Duration.zero;
  List<Duration> trackDurations = [];
  List<dynamic> script = [];

  Map<String, dynamic>? audioDurations = {};
  Future<Map<String, dynamic>>? cachedAudioDurations;

  stt.SpeechToText speech = stt.SpeechToText();
  String recordedText = '';

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    script = script_generator.createFirstScript(widget.dialogue);
    currentTrack = script[0];
    _initPlaylist();
    analyticsManager = AnalyticsManager(widget.userID, widget.documentID);
    analyticsManager.loadAnalyticsFromFirebase();
    _listenToPlayerStreams();
    cachedAudioDurations = getAudioDurationsFromNarratorStorage();
    firestoreService = UpdateFirestoreService.getInstance(
        widget.documentID, widget.generating, updatePlaylist, updateTrack);
    fileDurationUpdate = FileDurationUpdate.getInstance(
        widget.documentID, calculateTotalDurationAndUpdateTrackDurations);
  }

  void _listenToPlayerStreams() {
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (isPlaying) {
          analyticsManager.storeAnalytics(widget.documentID, 'completed');
        }
        _stop();
      }
    });

    player.currentIndexStream.listen((index) {
      if (index != null && index < script.length) {
        _handleTrackChange(script[index]);
        setState(() {
          currentTrack = script[index];
        });
      }
    });
  }

  Future<void> _initPlaylist() async {
    List<String> fileUrls =
        script.map((fileName) => _constructUrl(fileName)).toList();
    List<AudioSource> audioSources = fileUrls
        .where((url) => url.isNotEmpty)
        .map((url) => AudioSource.uri(Uri.parse(url)))
        .toList();
    playlist = ConcatenatingAudioSource(
        useLazyPreparation: false, children: audioSources);
    await player.setAudioSource(playlist);
    if (widget.generating) {
      _play();
    }
  }

  void updatePlaylist(snapshot) async {
    try {
      script = script_generator.parseAndCreateScript(
          snapshot.docs[0].data()["dialogue"] as List<dynamic>,
          widget.wordsToRepeat,
          widget.dialogue);
    } catch (e) {
      return;
    }

    var newScript = List.from(script);
    newScript.removeRange(0, playlist.children.length);

    List<String> fileUrls =
        newScript.map((fileName) => _constructUrl(fileName)).toList();
    final newTracks =
        fileUrls.map((url) => AudioSource.uri(Uri.parse(url))).toList();

    await playlist.addAll(newTracks);
    if (!widget.generating) {
      _play();
    }

    updateNumber++;
  }

  Future<void> updateTrack() async {
    CollectionReference colRef = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(widget.documentID)
        .collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();
    if (querySnap.docs.isNotEmpty) {
      await calculateTotalDurationAndUpdateTrackDurations(querySnap);
    }
  }

  String _constructUrl(String fileName) {
    if (fileName.startsWith("narrator_") ||
        fileName == "one_second_break" ||
        fileName == "five_second_break") {
      return "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_english/$fileName.mp3";
    } else {
      return "https://storage.googleapis.com/conversations_audio_files/${widget.documentID}/$fileName.mp3";
    }
  }

  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations
        .take(currentIndex)
        .fold(Duration.zero, (total, d) => total + d);
  }

  Stream<PositionData> get _positionDataStream {
    int previousIndex = -1;
    return Rx.combineLatest3<Duration, Duration, int, PositionData?>(
      player.positionStream.where((_) => !_isPaused),
      player.durationStream.whereType<Duration>(),
      player.currentIndexStream.whereType<int>().startWith(0),
      (position, duration, index) {
        bool hasIndexChanged = index != previousIndex;
        previousIndex = index;
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        if (hasIndexChanged) return null;
        if (position < duration) {
          return PositionData(
              position, duration, cumulativeDuration + position);
        }
        return null;
      },
    )
        .where((positionData) => positionData != null)
        .cast<PositionData>()
        .distinct((prev, current) => prev.position == current.position);
  }

  int findTrackIndexForPosition(double milliseconds) {
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) return i;
    }
    return trackDurations.length - 1;
  }

  Future<void> calculateTotalDurationAndUpdateTrackDurations(
      QuerySnapshot snapshot) async {
    totalDuration = Duration.zero;
    trackDurations = List<Duration>.filled(script.length, Duration.zero);
    audioDurations!.addAll(snapshot.docs[0].data() as Map<String, dynamic>);
    audioDurations!.addAll(await getAudioDurationsFromNarratorStorage());

    if (audioDurations!.isNotEmpty) {
      for (int i = 0; i < script.length; i++) {
        String fileName = script[i];
        double durationInSeconds = audioDurations?[fileName] ?? 0.0;
        Duration duration =
            Duration(milliseconds: (durationInSeconds * 1000).round());
        totalDuration += duration;
        trackDurations[i] = duration;
      }
      setState(() {});
    }

    if (updateNumber == widget.dialogue.length || !widget.generating) {
      calculateFinalTotalDuration();
    }
  }

  void calculateFinalTotalDuration() {
    finalTotalDuration =
        trackDurations.fold(Duration.zero, (total, d) => total + d);
    setState(() {});
  }

  Future<Map<String, dynamic>> getAudioDurationsFromNarratorStorage() async {
    if (cachedAudioDurations != null) {
      return cachedAudioDurations!;
    }

    CollectionReference colRef = FirebaseFirestore.instance.collection(
        'narrator_audio_files_durations/google_tts/narrator_english');
    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      DocumentSnapshot firstDoc = querySnap.docs.first;
      return firstDoc.data() as Map<String, dynamic>;
    }
    return {};
  }

  void _handleTrackChange(String newTrack) {
    if (newTrack.contains("target_language")) {
      // Update the previous phrase when a target_language phrase/word track starts
      previousTargetTrack = newTrack;
      print('The previous target track is: $previousTargetTrack');
    } else if (newTrack == "five_second_break") {
      // Start recording during the 5-second break
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    bool available = await speech.initialize();
    if (available) {
      speech.listen(
          onResult: (result) {
            setState(() {
              recordedText = result.recognizedWords;
            });
            print('You said: ${result.recognizedWords}');
          },
          localeId: 'de-DE');

      // Stop recording after the 5-second silent track ends
      await Future.delayed(const Duration(seconds: 5));
      speech.stop();

      // After recording, compare the result with the previous phrase
      _compareTranscriptionWithPhrase();
    }
  }

  void _compareTranscriptionWithPhrase() {
    if (previousTargetPhrase != null && recordedText.isNotEmpty) {
      if (recordedText
          .toLowerCase()
          .contains(previousTargetPhrase!.toLowerCase())) {
        print('Good job! You repeated the phrase correctly.');
        //_provideFeedback("Good job! You repeated the phrase correctly.");
      } else {
        print('Try again. The phrase didn\'t match.');
        //_provideFeedback("Try again. The phrase didn't match.");
      }
    }
  }

  // void _provideFeedback(String feedback) {
  //   // Show feedback to the user
  //   showDialog(
  //     context: context,
  //     builder: (context) {
  //       return AlertDialog(
  //         content: Text(feedback),
  //         actions: <Widget>[
  //           TextButton(
  //             child: const Text('OK'),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (!widget.generating) {
          if (!isStopped && isPlaying) await _pause();
          navigator.pop('reload');
        } else {
          if (!isStopped && isPlaying) await _pause();
          navigator.popUntil((route) => route.isFirst);
          navigator.pushReplacementNamed('/');
        }
      },
      child: FutureBuilder<int>(
        future: _getSavedPosition(),
        builder: (context, snapshot) {
          int savedPosition = snapshot.data ?? 0;
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                DialogueList(
                  dialogue: widget.dialogue,
                  currentTrack: currentTrack,
                  wordsToRepeat: widget.wordsToRepeat,
                ),
                PositionSlider(
                  positionDataStream: _positionDataStream,
                  totalDuration: totalDuration,
                  finalTotalDuration: finalTotalDuration,
                  isPlaying: isPlaying,
                  savedPosition: savedPosition,
                  findTrackIndexForPosition: findTrackIndexForPosition,
                  player: player,
                  cumulativeDurationUpTo: cumulativeDurationUpTo,
                  pause: _pause,
                ),
                ControlButtons(
                  player: player,
                  isPlaying: isPlaying,
                  onPlay: _play,
                  onPause: _pause,
                  onStop: _stop,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pause({bool analyticsOn = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    final currentPosition = positionData.inMilliseconds;
    int currentIndex = player.currentIndex ?? 0;

    await prefs.setInt(
        'savedPosition_${widget.documentID}_${widget.userID}', currentPosition);
    await prefs.setInt(
        'savedTrackIndex_${widget.documentID}_${widget.userID}', currentIndex);
    await prefs.setBool(
        "now_playing_${widget.documentID}_${widget.userID}", true);

    final nowPlayingKey = "now_playing_${widget.userID}";
    final nowPlayingList = prefs.getStringList(nowPlayingKey) ?? [];
    if (!nowPlayingList.contains(widget.documentID)) {
      nowPlayingList.add(widget.documentID);
    }
    await prefs.setStringList(nowPlayingKey, nowPlayingList);

    player.pause();
    if (mounted) {
      setState(() {
        isPlaying = false;
        _isPaused = true;
      });
    }
    if (analyticsOn) {
      analyticsManager.storeAnalytics(widget.documentID, 'pause');
    }
  }

  Future<void> _play() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition =
        prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedTrackIndex =
        prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');

    setState(() {
      isPlaying = true;
      _isPaused = false;
    });
    if (savedPosition != null && savedTrackIndex != null) {
      await player.seek(Duration(milliseconds: savedPosition),
          index: savedTrackIndex);
    }
    player.play();
    analyticsManager.storeAnalytics(widget.documentID, 'play');
  }

  Future<void> _stop() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('savedPosition_${widget.documentID}_${widget.userID}');
    prefs.remove('savedTrackIndex_${widget.documentID}_${widget.userID}');
    prefs.remove("now_playing_${widget.documentID}_${widget.userID}");

    List<String>? nowPlayingList =
        prefs.getStringList("now_playing_${widget.userID}");

    if (nowPlayingList != null) {
      nowPlayingList.remove(widget.documentID);
      await prefs.setStringList("now_playing_${widget.userID}", nowPlayingList);
    }

    player.stop();
    player.seek(Duration.zero, index: 0);
    setState(() {
      isPlaying = false;
      isStopped = true;
      currentTrack = script[0];
    });
  }

  Future<int> _getSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition =
        prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedIndex =
        prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');
    final position =
        savedPosition! + cumulativeDurationUpTo(savedIndex!).inMilliseconds;
    return position;
  }

  @override
  void dispose() {
    if (isPlaying) {
      _pause();
    }
    firestoreService?.dispose();
    fileDurationUpdate?.dispose();
    player.dispose();
    super.dispose();
  }
}
