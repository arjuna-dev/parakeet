import 'package:flutter/material.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/utils/constants.dart';

class AudioControls extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final ValueNotifier<RepetitionMode> repetitionMode;
  final bool generating;
  final bool hasWordsToReview;
  final VoidCallback? onReviewWords;

  const AudioControls({
    Key? key,
    required this.audioPlayerService,
    required this.repetitionMode,
    required this.generating,
    this.hasWordsToReview = false,
    this.onReviewWords,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (audioPlayerService.playlistInitialized == false) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: audioPlayerService.player.hasPrevious ? () => audioPlayerService.player.seekToPrevious() : null,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: audioPlayerService.isPlaying,
                  builder: (context, playing, child) {
                    return IconButton(
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        audioPlayerService.isPlaying.value = !audioPlayerService.isPlaying.value;
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: audioPlayerService.player.hasNext ? () => audioPlayerService.player.seekToNext() : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RepetitionModeSelector(
                  repetitionMode: repetitionMode,
                  generating: generating,
                ),
                SpeedSelector(
                  playbackSpeed: audioPlayerService.playbackSpeed,
                ),
              ],
            ),
          ),
          // Review Words Button (centered below)
          if (hasWordsToReview && !generating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () async {
                    // Pause audio before opening review
                    if (audioPlayerService.isPlaying.value) {
                      audioPlayerService.isPlaying.value = false;
                    }
                    // Call the review function
                    onReviewWords?.call();
                  },
                  icon: Icon(
                    Icons.quiz_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  ),
                  label: Text(
                    'Review',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RepetitionModeSelector extends StatelessWidget {
  final ValueNotifier<RepetitionMode> repetitionMode;
  final bool generating;

  const RepetitionModeSelector({
    Key? key,
    required this.repetitionMode,
    required this.generating,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<RepetitionMode>(
      offset: const Offset(0, 40),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Repetitions',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ],
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<RepetitionMode>>[
        PopupMenuItem<RepetitionMode>(
          value: RepetitionMode.normal,
          child: ValueListenableBuilder<RepetitionMode>(
            valueListenable: repetitionMode,
            builder: (context, mode, child) {
              return Row(
                children: [
                  const Text(
                    'Normal Repetitions',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (mode == RepetitionMode.normal)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check, size: 18),
                    ),
                ],
              );
            },
          ),
        ),
        PopupMenuItem<RepetitionMode>(
          value: RepetitionMode.less,
          child: ValueListenableBuilder<RepetitionMode>(
            valueListenable: repetitionMode,
            builder: (context, mode, child) {
              return Row(
                children: [
                  const Text(
                    'Less Repetitions',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (mode == RepetitionMode.less)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.check, size: 18),
                    ),
                ],
              );
            },
          ),
        ),
      ],
      onSelected: (RepetitionMode value) {
        if (generating) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please wait until we finish generating your audio to change this setting!'),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        } else {
          repetitionMode.value = value;
        }
      },
    );
  }
}

class SpeedSelector extends StatelessWidget {
  final ValueNotifier<double> playbackSpeed;

  const SpeedSelector({
    Key? key,
    required this.playbackSpeed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.speed,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        ValueListenableBuilder<double>(
          valueListenable: playbackSpeed,
          builder: (context, speed, child) {
            return DropdownButton<double>(
              value: speed,
              isDense: true,
              underline: Container(), // Remove the default underline
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              items: const [
                DropdownMenuItem(value: 0.7, child: Text('0.7x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 0.8, child: Text('0.8x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 0.9, child: Text('0.9x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 1.0, child: Text('1.0x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 1.25, child: Text('1.25x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 1.5, child: Text('1.5x', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 2.0, child: Text('2.0x', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (double? newValue) {
                if (newValue != null) {
                  playbackSpeed.value = newValue;
                }
              },
            );
          },
        ),
      ],
    );
  }
}
