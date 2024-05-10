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
      String fileUrl = await _constructUrl(fileName);
      if (!Uri.parse(fileUrl).isAbsolute) return null;
      return ProgressiveAudioSource(Uri.parse(fileUrl));
    }).toList();

    List<AudioSource> sources =
        (await Future.wait(futureSources)).whereType<AudioSource>().toList();

    playlist = ConcatenatingAudioSource(children: sources);

    try {
      await player.setAudioSource(playlist);
    } catch (e) {
      // catch load errors: 404, invalid url ...
      print("An error occurred while loading audio source: $e");
    } // This sets the audio source and prepares it for playback.
    player.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          totalDuration = duration;
        });
      }
      print(totalDuration);
    });
  }

  Future<String> _constructUrl(String fileName) async {
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
      print('File URL: $fileUrl'); // Add this line
      return fileUrl;
    } catch (e) {
      print("Failed to get file URL: $e");
      return '';
    }
  }

  Stream<PositionData> get _positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration, PositionData>(
          player.positionStream,
          player.bufferedPositionStream,
          player.durationStream.whereType<Duration>(),
          (position, bufferedPosition, duration) => PositionData(
                position,
                bufferedPosition,
                duration,
              ));

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
                    max: positionData.duration.inMilliseconds.toDouble(),
                    value: positionData.position.inMilliseconds
                        .clamp(0.0,
                            positionData.duration.inMilliseconds.toDouble())
                        .toDouble(),
                    onChanged: (value) {
                      player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Text(
                    "${formatDuration(positionData.position)} / ${formatDuration(positionData.duration)}",
                  ),
                ],
              );
            },
          ),
          Text('Now Playing: $currentTrack'),
          Row(
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
          ),
          // Control buttons as before
        ],
      ),
    );
  }

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
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}
