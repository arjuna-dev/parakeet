import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/ad_service.dart';
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
import 'package:string_similarity/string_similarity.dart';
import 'package:parakeet/utils/flutter_stt_language_codes.dart';
import 'dart:async';
import 'dart:io' show Platform;
import '../utils/constants.dart';
import 'package:parakeet/main.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String documentID;
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;

  const AudioPlayerScreen({
    Key? key,
    required this.documentID,
    required this.dialogue,
    required this.userID,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
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
  late List<AudioSource> positiveFeedbackAudio;
  late List<AudioSource> negativeFeedbackAudio;

  String currentTrack = '';
  String? previousTargetTrack;
  String? targetPhraseToCompareWith;
  String? voiceLanguageCode;
  bool isLanguageSupported = false;
  bool isPlaying = false;
  bool isStopped = false;
  bool _isPaused = false;
  int updateNumber = 0;
  bool speechRecognitionActive = false;
  bool? speechRecognitionSupported;
  Timer? _timer;
  Map<String, dynamic>? latestSnapshot;
  Map<int, String> filesToCompare = {};
  Map<String, dynamic>? existingBigJson;
  bool hasNicknameAudio = false;
  bool addressByNickname = true;

  Duration totalDuration = Duration.zero;
  Duration finalTotalDuration = Duration.zero;
  List<Duration> trackDurations = [];
  List<dynamic> script = [];

  Map<String, dynamic>? audioDurations = {};
  Future<Map<String, dynamic>>? cachedAudioDurations;

  stt.SpeechToText speech = stt.SpeechToText();
  String recordedText = '';

  int previousIndex = -1;
  bool _hasPremium = false;
  bool _hasShownInitialAd = false;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    script = script_generator.createFirstScript(widget.dialogue);
    currentTrack = script[0];
    analyticsManager = AnalyticsManager(widget.userID, widget.documentID);
    analyticsManager.loadAnalyticsFromFirebase();
    _listenToPlayerStreams();
    cachedAudioDurations = getAudioDurationsFromNarratorStorage();
    firestoreService = UpdateFirestoreService.getInstance(widget.documentID, widget.generating, updatePlaylist, updateTrack, saveSnapshot);
    fileDurationUpdate = FileDurationUpdate.getInstance(widget.documentID, calculateTotalDurationAndUpdateTrackDurations);
    getExistingBigJson();
    updateHasNicknameAudio().then((_) {
      _initPlaylist();
    });
    _loadAddressByNicknamePreference();
  }

  updateHasNicknameAudio() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String url = 'https://storage.googleapis.com/user_nicknames/${widget.userID}_1_nickname.mp3?timestamp=$timestamp';
    hasNicknameAudio = await urlExists(
      url,
    );
    setState(() {
      hasNicknameAudio = hasNicknameAudio;
    });
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userID).get();

    setState(() {
      _hasPremium = userDoc.data()?['premium'] ?? false;
    });

    if (!_hasPremium) {
      await AdService.loadInterstitialAd();
    }
  }

  void getExistingBigJson() async {
    if (!widget.generating) {
      final firestore = FirebaseFirestore.instance;
      final docRef = firestore.collection('chatGPT_responses').doc(widget.documentID).collection('all_breakdowns').doc('updatable_big_json');
      final doc = await docRef.get();
      if (doc.exists) {
        existingBigJson = doc.data();
      }
      print('existingBigJson: $existingBigJson');
    }
  }

  void _initAndStartRecording() async {
    await _initFeedbackAudioSources();
    await _checkIfLanguageSupported();
    _startRecording();
  }

  // Initialize feedback audio sources
  Future<void> _initFeedbackAudioSources() async {
    positiveFeedbackAudio = [AudioSource.asset('assets/amazing.mp3'), AudioSource.asset('assets/awesome.mp3'), AudioSource.asset('assets/you_did_great.mp3')];
    negativeFeedbackAudio = [AudioSource.asset('assets/meh.mp3'), AudioSource.asset('assets/you_can_do_better.mp3'), AudioSource.asset('assets/you_can_improve.mp3')];
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
        setState(() {
          currentTrack = script[index];
        });
        if (speechRecognitionActive) {
          _handleTrackChangeToCheckVoice(index);
        }
        setState(() {
          previousIndex = index;
        });
        print('currentTrack: $currentTrack');
      }
    });
  }

  Future<void> _initPlaylist() async {
    List<String> fileUrls = [];
    for (var fileName in script) {
      String url = await _constructUrl(fileName);
      if (url != "") {
        fileUrls.add(url);
      } else {
        print("Empty string URL for $fileName");
      }
    }

    if (fileUrls.isNotEmpty) {
      List<AudioSource> audioSources = fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();
      playlist = ConcatenatingAudioSource(useLazyPreparation: false, children: audioSources);
      await player.setAudioSource(playlist).catchError((error) {
        print("Error setting audio source: $error");
        return null;
      });

      // _showAd();
      await _play();
    } else {
      print("No valid URLs available to initialize the playlist.");
    }
  }

  void buildFilesToCompare(List<dynamic> script) {
    filesToCompare = {};
    int occurrences = 0;
    for (int i = 0; i < script.length; i++) {
      String fileName = script[i];
      if (!fileName.startsWith('\$')) {
        // This file is included in the playlist
        if (fileName == 'five_second_break') {
          // Map the playlistIndex to the phrase
          if (i > 0 && script[i - 1].startsWith('\$')) {
            String fileNameWithDollar = script[i - 1];
            String fileName = fileNameWithDollar.replaceFirst('\$', '');
            setState(() {
              filesToCompare[i - occurrences - 1] = fileName;
            });
            occurrences++;
          } else {
            print('Warning: Expected a \$-prefixed string before five_second_break at index $i');
          }
        }
      }
    }
  }

  void updatePlaylist(snapshot) async {
    try {
      script = script_generator.parseAndCreateScript(snapshot.docs[0].data()["dialogue"] as List<dynamic>, widget.wordsToRepeat, widget.dialogue);
    } catch (e) {
      return;
    }

    buildFilesToCompare(script);

    script = script.where((fileName) => !fileName.startsWith('\$')).toList();

    var newScript = List.from(script);
    newScript.removeRange(0, playlist.children.length);

    // Filter out files that start with a '$'
    newScript = newScript.where((fileName) => !fileName.startsWith('\$')).toList();

    List<String> fileUrls = [];
    for (var fileName in newScript) {
      fileUrls.add(await _constructUrl(fileName));
    }

    final newTracks = fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();
    await playlist.addAll(newTracks);
    if (!widget.generating) {
      await _play();
    }

    updateNumber++;
  }

  void saveSnapshot(QuerySnapshot snapshot) {
    if (snapshot.docs.isNotEmpty) {
      latestSnapshot = snapshot.docs[0].data() as Map<String, dynamic>?;
    }
  }

  Future<void> updateTrack() async {
    CollectionReference colRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('file_durations');
    QuerySnapshot querySnap = await colRef.get();
    if (querySnap.docs.isNotEmpty) {
      await calculateTotalDurationAndUpdateTrackDurations(querySnap);
    }
  }

  Future<String> _constructUrl(String fileName) async {
    if (fileName.startsWith("narrator_") || fileName == "one_second_break" || fileName == "five_second_break") {
      return "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_${widget.nativeLanguage}/$fileName.mp3";
    } else if (fileName == "nickname") {
      int randomNumber = Random().nextInt(5) + 1;
      print("hasNicknameAudio: $hasNicknameAudio");
      print("addressByNickname: $addressByNickname");
      if (hasNicknameAudio && addressByNickname) {
        print("had nickname audio, setting url");
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        return "https://storage.googleapis.com/user_nicknames/${widget.userID}_${randomNumber}_nickname.mp3?timestamp=$timestamp";
      } else {
        return "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_${widget.nativeLanguage}/narrator_greetings_$randomNumber.mp3";
      }
    } else {
      return "https://storage.googleapis.com/conversations_audio_files/${widget.documentID}/$fileName.mp3";
    }
  }

  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations.take(currentIndex).fold(Duration.zero, (total, d) => total + d);
  }

  Stream<PositionData> get _positionDataStream {
    int lastIndex = -1;
    return Rx.combineLatest3<Duration, Duration, int, PositionData?>(
      player.positionStream.where((_) => !_isPaused),
      player.durationStream.whereType<Duration>(),
      player.currentIndexStream.whereType<int>().startWith(0),
      (position, duration, index) {
        bool hasIndexChanged = index != lastIndex;
        lastIndex = index;
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        Duration totalPosition = cumulativeDuration + position;

        if (hasIndexChanged) return null;
        if (position < duration) {
          return PositionData(position, duration, totalPosition);
        }
        return null;
      },
    ).where((positionData) => positionData != null).cast<PositionData>().distinct((prev, current) => prev.position == current.position);
  }

  int findTrackIndexForPosition(double milliseconds) {
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) return i;
    }
    return trackDurations.length - 1;
  }

  Future<void> calculateTotalDurationAndUpdateTrackDurations(QuerySnapshot snapshot) async {
    totalDuration = Duration.zero;
    trackDurations = List<Duration>.filled(script.length, Duration.zero);
    audioDurations!.addAll(snapshot.docs[0].data() as Map<String, dynamic>);
    audioDurations!.addAll(await getAudioDurationsFromNarratorStorage());

    if (audioDurations!.isNotEmpty) {
      for (int i = 0; i < script.length; i++) {
        String fileName = script[i];
        double durationInSeconds = audioDurations?[fileName] ?? 0.0;
        Duration duration = Duration(milliseconds: (durationInSeconds * 1000).round());
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
    finalTotalDuration = trackDurations.fold(Duration.zero, (total, d) => total + d);
    setState(() {});
  }

  Future<Map<String, dynamic>> getAudioDurationsFromNarratorStorage() async {
    if (cachedAudioDurations != null) {
      return cachedAudioDurations!;
    }

    CollectionReference colRef = FirebaseFirestore.instance.collection('narrator_audio_files_durations/google_tts/narrator_${widget.nativeLanguage}');
    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      DocumentSnapshot firstDoc = querySnap.docs.first;
      return firstDoc.data() as Map<String, dynamic>;
    }
    return {};
  }

  String accessBigJson(Map<String, dynamic> listWithBigJson, String path) {
    final pattern = RegExp(r'(\D+)|(\d+)');
    final matches = pattern.allMatches(path);

    dynamic currentMap = listWithBigJson;
    for (var match in matches) {
      final key = match.group(0)!;
      final cleanedKey = key.replaceAll(RegExp(r'^_|_$'), '');

      if (int.tryParse(cleanedKey) != null) {
        // If it's a number, parse it as an index
        int index = int.parse(cleanedKey);
        currentMap = currentMap[index];
      } else {
        // If it's not a number, use it as a string key
        currentMap = currentMap[cleanedKey];
      }

      // If at any point currentMap is null, the key path is invalid
      if (currentMap == null) {
        throw Exception("Invalid path: $path");
      }
    }
    return currentMap;
  }

  void _handleTrackChangeToCheckVoice(int currentIndex) async {
    if (currentTrack == "five_second_break" && isLanguageSupported && currentIndex > previousIndex) {
      if (widget.generating) {
        setState(() {
          targetPhraseToCompareWith = accessBigJson(latestSnapshot!, filesToCompare[currentIndex]!);
        });
      } else {
        print("filesToCompare: $filesToCompare");
        print("currentIndex: $currentIndex");
        print('currentTrack: $currentTrack');
        setState(() {
          targetPhraseToCompareWith = accessBigJson(existingBigJson!, filesToCompare[currentIndex]!);
        });
      }
      if (speech.isListening) {
        await speech.stop(); // Wait for the speech recognition to stop
      }
      setState(() {
        recordedText = "";
      });
      _startRecording();
      Future.delayed(const Duration(seconds: 5), _compareTranscriptionWithPhrase);
    }
  }

  Future<String?> _fetchPreviousTargetPhrase(String documentId, String? previousTargetTrack) async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentId).collection('target_phrases').doc('updatable_target_phrases').get();

      if (documentSnapshot.exists) {
        Map<String, dynamic> data = documentSnapshot.data() as Map<String, dynamic>;
        return data[previousTargetTrack] as String?;
      } else {
        print('Document does not exist');
        setState(() {
          speechRecognitionSupported = false;
        });
        return null;
      }
    } catch (e) {
      print('Error fetching previous target phrase: $e');
      return null;
    }
  }

  Future<void> _checkIfLanguageSupported() async {
    bool isAvailable = await speech.initialize();
    if (isAvailable) {
      List<stt.LocaleName> systemLocales;

      if (kIsWeb) {
        // Get system locales from the browser
        voiceLanguageCode = languageCodes[widget.targetLanguage];
        print('Voice language code: $voiceLanguageCode');
        isLanguageSupported = true;
      } else {
        // Get system locales from the device
        systemLocales = await speech.locales();

        // Convert target language code to match system locale format
        String? targetLanguageCode = languageCodes[widget.targetLanguage]?.replaceAll('-', '_');

        isLanguageSupported = systemLocales.any((locale) => locale.localeId == targetLanguageCode);

        if (!isLanguageSupported) {
          print('Language not supported.');
          _timer?.cancel();
          speech.cancel();
          _showLanguageNotSupportedDialog();
          setState(() {
            speechRecognitionActive = false;
          });
        } else {
          voiceLanguageCode = languageCodes[widget.targetLanguage];
          print('Voice language code: $voiceLanguageCode');
        }
      }
    } else {
      print("Speech recognition is not available on this device.");
    }
  }

  void _showLanguageNotSupportedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Voice Feature Not Supported'),
          content:
              Text('The language you selected (${widget.targetLanguage}) is not supported on your device for speech recognition. You can continue with the exercise but the speech recognition feature will not work.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void displayPopupSTTSupport(BuildContext context) {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Feature Not Supported on Mobile Yet...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Platform.isIOS
                  ? const Text(
                      'We are working to bring speech recognition to mobile devices! For now, you can try it in the web app 🦜',
                    )
                  : const Text("We are working to bring speech recognition to mobile devices! For now, you can try it in the web app at app.parakeet.world 🦜"),
              const SizedBox(height: 8),
            ],
          ),
          actions: [
            Platform.isIOS
                ? TextButton(
                    onPressed: () {
                      launchURL(urlWebApp);
                    },
                    child: const Text('Try the Web App'))
                : Container(),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  speechRecognitionActive = false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _startRecording() async {
    setState(() {
      recordedText = "";
    });
    if (speech.isListening) {
      print("Returning early: speech recognition is already active.");
      return;
    }
    try {
      // Check if speech recognition is already listening
      if (!speech.isListening) {
        bool available = await speech.initialize();
        if (available) {
          // Start listening if initialization is successful
          try {
            speech.listen(
              onResult: (result) {
                setState(() {
                  recordedText = result.recognizedWords;
                });
              },
              localeId: languageCodes[widget.targetLanguage],
            );
          } catch (e) {
            print("Error: probably already listening");
          }

          // Set up a periodic timer to check if listening is still active
          _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
            if (!speech.isListening) {
              // Restart speech recognition if it stops
              print("Speech recognition stopped. Restarting...");
              _startRecording();
              timer.cancel();
            }
          });
        } else {
          print("Speech recognition is not available on this platform.");
        }
      } else {
        print("Speech recognition is already active.");
      }
    } catch (e) {
      print("Speech recognition was already active.");
    }
  }

  void _compareTranscriptionWithPhrase() async {
    print('starting comparison...');
    // print a timestamp
    print(DateTime.now().toIso8601String());
    if (targetPhraseToCompareWith != null) {
      // Normalize both strings: remove punctuation and convert to lowercase
      String normalizedRecordedText = _normalizeString(recordedText);
      // Duplicate normalizedRecordedText for web doubled text bug
      String doubledNormalizedRecordedText = '$normalizedRecordedText $normalizedRecordedText';
      String normalizedTargetPhrase = _normalizeString(targetPhraseToCompareWith!);

      print('you said: $normalizedRecordedText');
      print('target phrase: $normalizedTargetPhrase');

      // Calculate similarity
      double similarity = StringSimilarity.compareTwoStrings(
        normalizedRecordedText,
        normalizedTargetPhrase,
      );

      double similarityForDoubled = StringSimilarity.compareTwoStrings(
        doubledNormalizedRecordedText,
        normalizedTargetPhrase,
      );

      if (similarityForDoubled > similarity) {
        similarity = similarityForDoubled;
      }

      print('Similarity: $similarity');

      if (similarity >= 0.7) {
        print('Good job! You repeated the phrase correctly.');
        await _provideFeedback(isPositive: true);
      } else {
        print('Try again. The phrase didn\'t match.');
        await _provideFeedback(isPositive: false);
      }
    }
  }

// Helper method to normalize strings
  String _normalizeString(String input) {
    // Remove punctuation using a regular expression and convert to lowercase
    return input.replaceAll(RegExp(r'[^\w\s]+'), '').toLowerCase();
  }

  AudioSource getRandomAudioSource(List<AudioSource> audioList) {
    final random = Random();
    int index = random.nextInt(audioList.length);
    return audioList[index];
  }

// Method to provide audio feedback
  Future<void> _provideFeedback({required bool isPositive}) async {
    // Pause the main player if it's playing
    if (player.playing) {
      await player.pause();
    }

    // Create a separate AudioPlayer for feedback to avoid conflicts
    AudioPlayer feedbackPlayer = AudioPlayer();

    // Set the appropriate audio source
    await feedbackPlayer.setAudioSource(
      isPositive ? getRandomAudioSource(positiveFeedbackAudio) : getRandomAudioSource(negativeFeedbackAudio),
    );

    // Play the feedback
    await feedbackPlayer.play();

    // Wait for the feedback to finish
    await feedbackPlayer.processingStateStream.firstWhere(
      (state) => state == ProcessingState.completed,
    );

    // Release the feedback player resources
    await feedbackPlayer.dispose();

    // Resume the main player if it was playing before
    if (!isStopped && isPlaying) {
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScreenWrapper(
      child: PopScope(
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
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Check Pronunciation:'),
                        Switch(
                          value: speechRecognitionActive,
                          onChanged: (bool value) {
                            if (value & kIsWeb) {
                              _initAndStartRecording();
                            } else if (value & !kIsWeb) {
                              displayPopupSTTSupport(context);
                            } else {
                              speech.stop();
                              speech.cancel();
                              _timer?.cancel();
                            }
                            setState(() {
                              speechRecognitionActive = value;
                            });
                          },
                        ),
                      ],
                    ),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _pause({bool analyticsOn = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    final currentPosition = positionData.inMilliseconds;
    int currentIndex = player.currentIndex ?? 0;

    await prefs.setInt('savedPosition_${widget.documentID}_${widget.userID}', currentPosition);
    await prefs.setInt('savedTrackIndex_${widget.documentID}_${widget.userID}', currentIndex);
    await prefs.setBool("now_playing_${widget.documentID}_${widget.userID}", true);

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
    final savedPosition = prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedTrackIndex = prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');

    setState(() {
      isPlaying = true;
      _isPaused = false;
    });

    if (savedPosition != null && savedTrackIndex != null) {
      await player.seek(Duration(milliseconds: savedPosition), index: savedTrackIndex);
    }
    player.play();

    // Show ad for non-premium users every time they start playing
    if (!_hasPremium && !_hasShownInitialAd) {
      _hasShownInitialAd = true; // Prevent showing ad multiple times in same session
      await AdService.showInterstitialAd(
        onAdShown: () async {
          await _pause();
        },
        onAdDismissed: () async {
          await _play();
        },
      );
    }

    analyticsManager.storeAnalytics(widget.documentID, 'play');
  }

  Future<void> _stop() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('savedPosition_${widget.documentID}_${widget.userID}');
    prefs.remove('savedTrackIndex_${widget.documentID}_${widget.userID}');
    prefs.remove("now_playing_${widget.documentID}_${widget.userID}");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_${widget.userID}");

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
    final savedPosition = prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedIndex = prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');
    final position = savedPosition! + cumulativeDurationUpTo(savedIndex!).inMilliseconds;
    return position;
  }

  Future<void> _loadAddressByNicknamePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      addressByNickname = prefs.getBool('addressByNickname') ?? true;
    });
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
