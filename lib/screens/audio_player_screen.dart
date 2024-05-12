import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AudioPlayerScreen extends StatefulWidget {
  final List<dynamic> script;
  final String responseDbId;

  const AudioPlayerScreen(
      {Key? key, required this.script, required this.responseDbId})
      : super(key: key);

  @override
  AudioPlayerScreenState createState() => AudioPlayerScreenState();
}

class AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer player;
  late ConcatenatingAudioSource playlist;
  String currentTrack = '';
  bool isPlaying = false;
  Duration totalDuration = Duration.zero;
  Duration currentPosition = Duration.zero;
  Duration cumulativeTimeBeforeCurrent = Duration.zero;
  List<Duration> trackDurations = [];

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    currentTrack = widget.script[0];
    _initPlaylist();
  }

  Future<void> _initPlaylist() async {
    List<Future<AudioSource?>> futureSources =
        widget.script.map((fileName) async {
      List<dynamic> urlData = await _constructUrl(fileName);
      String fileUrl = urlData[0];
      Duration duration = Duration(
          milliseconds: (double.parse(urlData[1].toString()) * 1000).round());
      totalDuration += duration;
      trackDurations.add(duration); // Store each track's duration
      if (!Uri.parse(fileUrl).isAbsolute) return null;
      return ProgressiveAudioSource(Uri.parse(fileUrl));
    }).toList();

    List<AudioSource> sources =
        (await Future.wait(futureSources)).whereType<AudioSource>().toList();
    playlist = ConcatenatingAudioSource(children: sources);

    try {
      await player.setAudioSource(playlist);
    } catch (e) {
      print("An error occurred while loading audio source: $e");
    }
  }

  Future<List> _constructUrl(String fileName) async {
    String filePath;
    if (fileName.startsWith("narrator_") ||
        fileName == "one_second_break" ||
        fileName == "five_second_break") {
      filePath =
          "gs://narrator_audio_files/google_tts/narrator_english/$fileName.mp3";
    } else {
      filePath =
          "gs://conversations_audio_files/${widget.responseDbId}/$fileName.mp3";
    }

    try {
      // Get the reference to the file in Firebase Storage
      Reference ref = FirebaseStorage.instance.ref().child(filePath);
      // Get the download URL
      String fileUrl = await ref.getDownloadURL();
      final metadata = await ref.getMetadata();

      return [fileUrl, metadata.customMetadata!['duration']];
    } catch (e) {
      print("Failed to get file URL: $e");
      return ["", ""];
    }
  }

  Duration cumulativeDurationUpTo(int currentIndex) {
    return trackDurations
        .take(currentIndex)
        .fold(Duration.zero, (sum, d) => sum + d);
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, int, PositionData>(
          player.positionStream,
          player.durationStream.whereType<Duration>(),
          player.currentIndexStream.whereType<int>().startWith(0),
          (position, duration, index) {
        Duration cumulativeDuration = cumulativeDurationUpTo(index);
        return PositionData(
          position,
          position + duration, // Buffered position might not be needed as is
          duration,
          cumulativeDuration + position,
        );
      });

  Duration calculateSumOfPreviousDurations(int currentIndex) {
    return Duration(
        milliseconds: playlist.children
            .take(currentIndex)
            .map((source) =>
                (source as ProgressiveAudioSource).duration!.inMilliseconds)
            .fold(0, (sum, element) => sum + element));
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Player'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
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
                    value: positionData.cumulativePosition.inMilliseconds
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
                    },
                  ),
                  Text(
                    "${formatDuration(positionData.cumulativePosition)} / ${formatDuration(totalDuration)}",
                  ),
                ],
              );
            },
          ),
          Text('Now Playing: $currentTrack'),
          controlButtons(), // It's cleaner to move control buttons to a separate method
        ],
      ),
    );
  }

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

  void _play() async {
    setState(() => isPlaying = true);
    await player.play();
    player.currentIndexStream.listen((index) {
      if (index != null && index < widget.script.length) {
        setState(() {
          currentTrack = widget.script[index];
        });
      }
    });
  }

  void _pause() {
    player.pause();
    setState(() => isPlaying = false);
  }

  void _stop() {
    player.stop();
    player.seek(Duration.zero);
    setState(() {
      isPlaying = false;
      //currentTrack = widget.script[0];
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}

String formatDuration(Duration d) {
  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
  return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
}

class PositionData {
  final Duration position; // Current position within the track
  final Duration bufferedPosition;
  final Duration duration; // Duration of the current track
  final Duration cumulativePosition; // Cumulative position across all tracks

  PositionData(this.position, this.bufferedPosition, this.duration,
      this.cumulativePosition);
}
