import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Map<String, dynamic> script;
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
  bool isPlaying = false;
  String currentTrack = '';

  @override
  void initState() {
    super.initState();
    player = AudioPlayer();
    _initPlaylist();
  }

  Future<void> _initPlaylist() async {
    List<AudioSource> sources = [];
    try {
      // Iterate over the script to create sources in order
      for (var fileName in widget.script["script"]) {
        if (fileName == 'one_second_break') {
          sources.add(SilenceAudioSource(duration: const Duration(seconds: 1)));
        } else if (fileName == 'five_second_break') {
          sources.add(SilenceAudioSource(duration: const Duration(seconds: 5)));
        } else {
          String fileUrl;
          if (fileName.startsWith("narrator_")) {
            fileUrl =
                "https://storage.googleapis.com/narrator_audio_files/google_tts/narrator_english/$fileName.mp3";
          } else {
            fileUrl =
                "https://storage.googleapis.com/conversations_audio_files/${widget.responseDbId}/$fileName.mp3";
          }
          sources.add(AudioSource.uri(Uri.parse(fileUrl)));
        }
      }

      playlist = ConcatenatingAudioSource(children: sources);
      await player.setAudioSource(playlist);
    } catch (e) {
      print('Error initializing playlist: $e');
    }
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
          Text('Now Playing: $currentTrack'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: isPlaying ? null : () => _play(),
              ),
              IconButton(
                icon: const Icon(Icons.pause),
                onPressed: isPlaying ? () => _pause() : null,
              ),
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: isPlaying ? () => _stop() : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _play() async {
    setState(() => isPlaying = true);
    await player.play();
    player.currentIndexStream.listen((index) {
      if (index != null && index < playlist.children.length) {
        setState(() {
          currentTrack = playlist.children[index] as String;
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
    setState(() {
      isPlaying = false;
      currentTrack = '';
    });
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
