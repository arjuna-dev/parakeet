import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:collection';
import 'package:parakeet/utils/script_generator.dart' as script_generator;

// This is the main screen for the audio player
// ignore: must_be_immutable
class AudioPlayerScreen extends StatefulWidget {
  final String documentID; // Database ID for the response
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final bool generating;

  const AudioPlayerScreen(
      {Key? key,
      required this.documentID,
      required this.dialogue,
      required this.userID,
      required this.title,
      required this.wordsToRepeat,
      required this.scriptDocumentId,
      required this.generating})
      : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  FirestoreService? firestoreService;
  FileDurationUpdate? fileDurationUpdate;
  late AudioPlayer player; // The audio player
  late ConcatenatingAudioSource playlist; // The playlist
  String currentTrack = ''; // The current track
  bool isPlaying = false; // Whether the player is playing
  bool isStopped = false; // Whether the player is stopped
  Duration totalDuration = Duration.zero; // The total duration of all tracks
  Duration finalTotalDuration = Duration.zero;
  Duration currentPosition =
      Duration.zero; // The current position within the track
  Duration cumulativeTimeBeforeCurrent =
      Duration.zero; // Cumulative time before the current track
  List<Duration> trackDurations = []; // List of durations for each track
  bool _isPaused = false; // Whether the player is paused
  int? _lastMatchedIndex;
  List<dynamic> script = [];
  int updateNumber = 0;
  Map<String, dynamic>? audioDurations = {};
  Future<Map<String, dynamic>>?
      cachedAudioDurations; // Future to cache audio durations

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    script = script_generator.createFirstScript(widget.dialogue);
    currentTrack = script[0];
    _initPlaylist();

    // Listen to the playerSequenceCompleteStream
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // Stop the player when the end of the playlist is reached
        _stop();
      }
    });

    // Initialize the cached audio durations Future
    cachedAudioDurations = getAudioDurationsFromNarratorStorage();

    firestoreService = FirestoreService.getInstance(
        widget.documentID, widget.generating, updatePlaylist, updateTrack);
    fileDurationUpdate = FileDurationUpdate.getInstance(
        widget.documentID, calculateTotalDurationAndUpdateTrackDurations);
  }

  Future<Map<String, dynamic>> getAudioDurationsFromNarratorStorage() async {
    if (cachedAudioDurations != null) {
      return cachedAudioDurations!;
    }

    CollectionReference colRef = FirebaseFirestore.instance.collection(
        'narrator_audio_files_durations/google_tts/narrator_english');

    QuerySnapshot querySnap = await colRef.get();

    if (querySnap.docs.isNotEmpty) {
      // Get the first document
      DocumentSnapshot firstDoc = querySnap.docs.first;
      // Save its data to audioDurations
      return firstDoc.data() as Map<String, dynamic>;
    }

    return {};
  }

  Future<void> calculateTotalDurationAndUpdateTrackDurations(snapshot) async {
    totalDuration = Duration.zero;
    trackDurations = List<Duration>.filled(script.length, Duration.zero);
    audioDurations!.addAll(snapshot.docs[0].data() as Map<String, dynamic>);

    var narratorAudioDurations = await getAudioDurationsFromNarratorStorage();
    audioDurations!.addAll(narratorAudioDurations);

    if (audioDurations!.isNotEmpty) {
      for (int i = 0; i < script.length; i++) {
        String fileName = script[i];
        double durationInSeconds = 0.0;
        if (audioDurations?.containsKey(fileName) == true) {
          durationInSeconds = audioDurations?[fileName] as double;
        }
        // else {
        //   print('file not found');
        // }
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
        trackDurations.fold(Duration.zero, (sum, d) => sum + d);
    setState(() {});
  }

  // This method initializes the playlist
  Future<void> _initPlaylist() async {
    List<String> fileUrls =
        script.map((fileName) => _constructUrl(fileName)).toList();
    List<AudioSource> audioSources = fileUrls
        // ignore: unnecessary_null_comparison
        .where((url) => url != null)
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
    // to not add tracks already added to the playlist
    newScript.removeRange(0, playlist.children.length);

    // Construct URLs for the new files
    List<String> fileUrls =
        newScript.map((fileName) => _constructUrl(fileName)).toList();
    final newTracks =
        fileUrls.map((url) => AudioSource.uri(Uri.parse(url))).toList();

    await playlist.addAll(newTracks);
    if (!widget.generating) {
      _play();
    }

    updateNumber++;

    print("updated!!");
  }

  // This method constructs the URL for a file
  String _constructUrl(String fileName) {
    String fileUrl;
    if (fileName.startsWith("narrator_") ||
        fileName == "one_second_break" ||
        fileName == "five_second_break") {
      fileUrl =
          "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_english/${fileName}.mp3";
    } else {
      fileUrl =
          "https://storage.googleapis.com/conversations_audio_files/${widget.documentID}/${fileName}.mp3";
    }

    return fileUrl;
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

  // This method calculates the cumulative duration up to a certain index
  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations
        .take(currentIndex)
        .fold(Duration.zero, (sum, d) => sum + d);
  }

  // This method creates a stream of position data
  Stream<PositionData> get _positionDataStream {
    int previousIndex = -1;
    return Rx.combineLatest3<Duration, Duration, int, PositionData?>(
            player.positionStream.where((_) => !_isPaused),
            player.durationStream.whereType<Duration>(),
            player.currentIndexStream.whereType<int>().startWith(0),
            (position, duration, index) {
      // Debug prints
      //print("Position: $position, Duration: $duration, Index: $index");

      bool hasIndexChanged = index != previousIndex;
      previousIndex = index;
      Duration cumulativeDuration = cumulativeDurationUpTo(index);
      if (hasIndexChanged) {
        return null;
      } else if (position < duration) {
        return PositionData(
          position,
          duration,
          cumulativeDuration + position,
        );
      } else {
        return null;
      }
    })
        .where((positionData) => positionData != null)
        .cast<PositionData>()
        .distinct((prev, current) => prev.position == current.position);
  }

  // This method finds the track index for a position
  int findTrackIndexForPosition(double milliseconds) {
    int cumulative = 0;
    for (int i = 0; i < trackDurations.length; i++) {
      cumulative += trackDurations[i].inMilliseconds;
      if (cumulative > milliseconds) {
        return i;
      }
    }
    return trackDurations.length - 1;
  }

  // This method builds the widget
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) {
          return;
        }
        final NavigatorState navigator = Navigator.of(context);
        if (!widget.generating) {
          if (!isStopped) {
            await _pause();
          }
          navigator.pop('reload');
        } else {
          if (!isStopped) {
            await _pause();
          }
          //remove all the stacks and reload the home page
          navigator.popUntil((route) => route.isFirst);
          navigator.pushReplacementNamed('/');
        }
      },
      child: FutureBuilder<int>(
        builder: (context, snapshot) {
          int savedPosition = snapshot.data ?? 0;
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
            ),
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.dialogue.length,
                    itemBuilder: (context, index) {
                      String dialogueTarget =
                          widget.dialogue[index]["target_language"];
                      String dialogueNative =
                          widget.dialogue[index]["native_language"];
                      bool isMatch = currentTrack.split('_').length >= 2 &&
                          currentTrack.split('_').take(2).join('_') ==
                              "dialogue_$index";
                      if (isMatch) {
                        _lastMatchedIndex = index;
                      }
                      return Column(
                        children: [
                          ListTile(
                            title: Text("Sentence number : ${index + 1}"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dialogueNative),
                                RichText(
                                  text: TextSpan(
                                    children:
                                        dialogueTarget.split(' ').map((word) {
                                      final match =
                                          widget.wordsToRepeat.contains(word);
                                      return TextSpan(
                                        text: '$word ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: match
                                              ? Colors.green
                                              : (index == _lastMatchedIndex
                                                  ? Colors.purple
                                                  : Colors.black),
                                          fontWeight: index == _lastMatchedIndex
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          decoration: match
                                              ? TextDecoration.underline
                                              : TextDecoration.none,
                                          decorationColor: match
                                              ? const Color.fromARGB(
                                                  255, 21, 87, 25)
                                              : null, // Darker green for underline

                                          decorationThickness:
                                              match ? 2.0 : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                StreamBuilder<PositionData>(
                  stream: _positionDataStream,
                  builder: (context, snapshot) {
                    final positionData = snapshot.data;
                    if (positionData == null) {
                      return const CircularProgressIndicator();
                    }
                    return Column(
                      children: [
                        Slider(
                          min: 0.0,
                          max: totalDuration.inMilliseconds.toDouble(),
                          value: isPlaying
                              ? positionData.cumulativePosition.inMilliseconds
                                  .clamp(0, totalDuration.inMilliseconds)
                                  .toDouble()
                              : savedPosition
                                  .clamp(0, totalDuration.inMilliseconds)
                                  .toDouble(),
                          onChanged: (value) {
                            final trackIndex = findTrackIndexForPosition(value);
                            player.seek(
                                Duration(
                                    milliseconds: value.toInt() -
                                        cumulativeDurationUpTo(trackIndex)
                                            .inMilliseconds),
                                index: trackIndex);
                            if (_isPaused) {
                              _pause();
                              setState(() {
                                positionData.cumulativePosition =
                                    Duration(milliseconds: value.toInt());
                              });
                            }
                          },
                        ),
                        Text(
                          finalTotalDuration == Duration.zero
                              ? formatDuration(isPlaying
                                  ? positionData.cumulativePosition
                                  : Duration(milliseconds: savedPosition))
                              : "${formatDuration(isPlaying ? positionData.cumulativePosition : Duration(milliseconds: savedPosition))} / ${formatDuration(finalTotalDuration)}",
                        ),
                      ],
                    );
                  },
                ),
                controlButtons(), // Play, pause, stop, skip buttons
              ],
            ),
          );
        },
        future: _getSavedPosition(),
      ),
    );
  }

  // This method creates the control buttons
  Widget controlButtons() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed:
                player.hasPrevious ? () => player.seekToPrevious() : null,
          ),
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: isPlaying ? _pause : _play,
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _stop,
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: player.hasNext ? () => player.seekToNext() : null,
          ),
        ],
      );

// This method pauses the audio
  Future<void> _pause() async {
    final prefs = await SharedPreferences.getInstance();
    final positionData = await player.positionStream.first;
    final currentPosition = positionData.inMilliseconds;
    int currentIndex = 0;
    player.currentIndexStream.listen((index) {
      currentIndex = index ?? 0;
    });

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
  }

// This method plays the audio
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
    print('savedPosition: $savedPosition, savedTrackIndex: $savedTrackIndex');
    player.play();
    player.currentIndexStream.listen((index) {
      if (index != null && index < script.length) {
        setState(() {
          currentTrack = script[index];
        });
      }
    });
  }

  // This method stops the audio
  Future<void> _stop() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('savedPosition_${widget.documentID}_${widget.userID}');
    prefs.remove('savedTrackIndex_${widget.documentID}_${widget.userID}');
    prefs.remove("now_playing_${widget.documentID}_${widget.userID}");
    // Retrieve the now playing list
    List<String>? nowPlayingList =
        prefs.getStringList("now_playing_${widget.userID}");

    // Check if the list is not null
    if (nowPlayingList != null) {
      // Remove widget.documentID from the list if it exists
      nowPlayingList.remove(widget.documentID);

      // Save the updated list back to preferences
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

  // This method gets the saved position from shared preferences
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

  // This method disposes the player when the widget is disposed
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

// This method formats a duration as a string
String formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
  return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

// This class represents the position data
class PositionData {
  final Duration position; // Current position within the track
  final Duration duration; // Duration of the current track
  Duration cumulativePosition; // Cumulative position across all tracks

  PositionData(this.position, this.duration, this.cumulativePosition);
}

class FirestoreService extends ChangeNotifier {
  static FirestoreService? _instance;

  late Stream<QuerySnapshot> _stream;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Function updatePlaylist;
  Function updateTrack;
  Queue<QuerySnapshot> queue = Queue<QuerySnapshot>();
  bool isUpdating = false;

  FirestoreService._privateConstructor(this.updatePlaylist, this.updateTrack);

  static FirestoreService getInstance(String documentID, bool generating,
      Function updatePlaylist, Function updateTrack) {
    _instance ??=
        FirestoreService._privateConstructor(updatePlaylist, updateTrack);
    _instance!._initializeStream(documentID, generating);
    return _instance!;
  }

  void _initializeStream(String documentID, bool generating) {
    _stream = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('all_breakdowns')
        .snapshots();
    _streamSubscription = _stream.listen((snapshot) {
      queue.add(snapshot);
      processQueue(updateTrack, generating);
    });
  }

  Future<void> processQueue(updateTrack, generating) async {
    if (!isUpdating && queue.isNotEmpty) {
      isUpdating = true;
      await updatePlaylist(queue.removeFirst());
      isUpdating = false;
      if (queue.isEmpty && generating) {
        updateTrack();
      }
      processQueue(updateTrack, generating);
    }
  }

  Stream<QuerySnapshot> get stream => _stream;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _instance = null;
    queue.clear();
    super.dispose();
  }
}

class FileDurationUpdate extends ChangeNotifier {
  static FileDurationUpdate? _instance;

  late Stream<QuerySnapshot> _stream;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Queue<QuerySnapshot> queue = Queue<QuerySnapshot>();
  bool isUpdating = false;
  Function calculateTotalDurationAndUpdateTrackDurations;

  FileDurationUpdate._privateConstructor(
      this.calculateTotalDurationAndUpdateTrackDurations);

  static FileDurationUpdate getInstance(String documentID,
      Function calculateTotalDurationAndUpdateTrackDurations) {
    _instance ??= FileDurationUpdate._privateConstructor(
        calculateTotalDurationAndUpdateTrackDurations);
    _instance!._initializeStream(documentID);
    return _instance!;
  }

  void _initializeStream(String documentID) {
    _stream = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('file_durations')
        .snapshots();
    _streamSubscription = _stream.listen((snapshot) {
      queue.add(snapshot);
      processQueue();
    });
  }

  Future<void> processQueue() async {
    if (!isUpdating && queue.isNotEmpty) {
      isUpdating = true;
      await calculateTotalDurationAndUpdateTrackDurations(queue.removeFirst());
      isUpdating = false;
      processQueue();
    }
  }

  Stream<QuerySnapshot> get stream => _stream;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _instance = null;
    queue.clear();
    super.dispose();
  }
}
