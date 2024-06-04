import 'package:auralearn/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// This is the main screen for the audio player
// ignore: must_be_immutable
class AudioPlayerScreen extends StatefulWidget {
  final List<dynamic> script; //List of audio file names
  final String documentID; // Database ID for the response
  final List<dynamic> dialogue;
  final String userID;
  final String title;
  Map<String, dynamic>? audioDurations;
  String? scriptDocumentId;
  List<String>? wordsToRepeat;

  AudioPlayerScreen(
      {Key? key,
      required this.script,
      required this.documentID,
      required this.dialogue,
      required this.userID,
      required this.title,
      this.scriptDocumentId,
      this.audioDurations,
      this.wordsToRepeat})
      : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer player; // The audio player
  late ConcatenatingAudioSource playlist; // The playlist
  String currentTrack = ''; // The current track
  bool isPlaying = false; // Whether the player is playing
  Duration totalDuration = Duration.zero; // The total duration of all tracks
  Duration currentPosition =
      Duration.zero; // The current position within the track
  Duration cumulativeTimeBeforeCurrent =
      Duration.zero; // Cumulative time before the current track
  List<Duration> trackDurations = []; // List of durations for each track
  bool _isPaused = false; // Whether the player is paused
  int? _lastMatchedIndex;

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    currentTrack = widget.script[0];
    _initPlaylist(); // Initialize the playlist

    // Listen to the playerSequenceCompleteStream
    player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        _stop();
      }
    });
  }

  // This method initializes the playlist
  Future<void> _initPlaylist() async {
    List<Future<String?>> fileUrls =
        widget.script.map((fileName) => _constructUrl(fileName)).toList();
    List<String?> results = await Future.wait(fileUrls);
    List<AudioSource> audioSources = results
        .where((url) => url != null)
        .map((url) => AudioSource.uri(Uri.parse(url!)))
        .toList();
    playlist = ConcatenatingAudioSource(children: audioSources);
    player.setAudioSource(playlist);

    // Calculate totalDuration and update trackDurations
    totalDuration = Duration.zero;
    trackDurations = List<Duration>.filled(widget.script.length, Duration.zero);
    if (widget.audioDurations != null) {
      for (int i = 0; i < widget.script.length; i++) {
        String fileName = widget.script[i];
        double durationInSeconds;
        if (widget.audioDurations?[fileName].runtimeType == String) {
          durationInSeconds = double.parse(widget.audioDurations?[fileName]);
        } else {
          durationInSeconds = widget.audioDurations?[fileName] as double;
        }
        Duration duration =
            Duration(milliseconds: (durationInSeconds * 1000).round());
        totalDuration += duration;
        trackDurations[i] = duration;
      }
    }
  }

  // This method constructs the URL for a file
  Future<String> _constructUrl(String fileName) async {
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

  // This method calculates the cumulative duration up to a certain index
  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations
        .take(currentIndex)
        .fold(Duration.zero, (sum, d) => sum + d);
  }

  // This method creates a stream of position data
  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, int, PositionData>(
          player.positionStream.where((_) => !_isPaused),
          player.durationStream.whereType<Duration>(),
          player.currentIndexStream.whereType<int>().startWith(0),
          (position, duration, index) {
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        if (position < duration) {
          return PositionData(
            position,
            position + duration, // Buffered position might not be needed as is
            duration,
            cumulativeDuration + position,
          );
        } else {
          return PositionData(
            position,
            position + duration, // Buffered position might not be needed as is
            duration,
            cumulativeDuration + duration,
          );
        }
      }).distinct((prev, current) => prev.position == current.position);

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
    return FutureBuilder<int>(
      builder: (context, snapshot) {
        int savedPosition = snapshot.data ?? 0;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                dispose();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) =>
                          const Home()), // replace HomeScreen with your actual home screen widget
                  (Route<dynamic> route) => false,
                );
              },
            ),
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
                    String dialogue = widget.dialogue[index]["target_language"];
                    bool isMatch = currentTrack.split('_').length >= 2 &&
                        currentTrack.split('_').take(2).join('_') ==
                            "dialogue_$index";
                    if (isMatch) {
                      _lastMatchedIndex = index;
                    }
                    return Text(
                      dialogue,
                      style: TextStyle(
                        color: index == _lastMatchedIndex
                            ? Colors.red
                            : Colors.black,
                        fontWeight: index == _lastMatchedIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
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
                            : savedPosition.toDouble(),
                        onChanged: (value) {
                          final trackIndex = findTrackIndexForPosition(value);
                          player.seek(
                              Duration(
                                  milliseconds: value.toInt() -
                                      cumulativeDurationUpTo(trackIndex)
                                          .inMilliseconds),
                              index: trackIndex);
                          if (_isPaused) {
                            setState(() {
                              positionData.cumulativePosition =
                                  Duration(milliseconds: value.toInt());
                            });
                          }
                        },
                      ),
                      Text(
                        "${formatDuration(isPlaying ? positionData.cumulativePosition : Duration(milliseconds: savedPosition))} / ${formatDuration(totalDuration)}",
                      ),
                    ],
                  );
                },
              ),
              Text('Now Playing: $currentTrack'),
              controlButtons(), // Play, pause, stop, skip buttons
            ],
          ),
        );
      },
      future: _getSavedPosition(),
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
            onPressed: isPlaying ? _stop : null,
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
    setState(() {
      isPlaying = false;
      _isPaused = true;
    });
  }

// This method plays the audio
  Future<void> _play() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition =
        prefs.getInt('savedPosition_${widget.documentID}_${widget.userID}');
    final savedTrackIndex =
        prefs.getInt('savedTrackIndex_${widget.documentID}_${widget.userID}');
    if (savedPosition != null && savedTrackIndex != null) {
      await player.seek(Duration(milliseconds: savedPosition),
          index: savedTrackIndex);
    }
    setState(() {
      isPlaying = true;
      _isPaused = false;
    });
    await player.play();
    player.currentIndexStream.listen((index) {
      if (index != null && index < widget.script.length) {
        setState(() {
          currentTrack = widget.script[index];
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
    await prefs.setStringList("now_playing_${widget.userID}", []);

    player.stop();
    player.seek(Duration.zero, index: 0);
    setState(() {
      isPlaying = false;
      currentTrack = widget.script[0];
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
  final Duration bufferedPosition;
  final Duration duration; // Duration of the current track
  Duration cumulativePosition; // Cumulative position across all tracks

  PositionData(this.position, this.bufferedPosition, this.duration,
      this.cumulativePosition);
}
