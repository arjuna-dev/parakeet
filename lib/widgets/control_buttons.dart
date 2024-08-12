import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ControlButtons extends StatelessWidget {
  final AudioPlayer player;
  final bool isPlaying;
  final VoidCallback onPlay;
  final Future<void> Function({bool analyticsOn}) onPause;
  final Future<void> Function() onStop;

  const ControlButtons({
    Key? key,
    required this.player,
    required this.isPlaying,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: player.hasPrevious ? () => player.seekToPrevious() : null,
        ),
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: isPlaying ? () => onPause() : onPlay,
        ),
        IconButton(
          icon: const Icon(Icons.stop),
          onPressed: onStop,
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: player.hasNext ? () => player.seekToNext() : null,
        ),
      ],
    );
  }
}
