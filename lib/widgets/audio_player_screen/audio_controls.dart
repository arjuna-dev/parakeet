import 'package:flutter/material.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/utils/constants.dart';

class AudioControls extends StatelessWidget {
  final AudioPlayerService audioPlayerService;
  final ValueNotifier<RepetitionMode> repetitionMode;
  final bool generating;
  final bool hasWordsToReview;
  final VoidCallback? onReviewWords;
  final bool isCompleted;
  final VoidCallback? onMarkCompleted;

  const AudioControls({
    Key? key,
    required this.audioPlayerService,
    required this.repetitionMode,
    required this.generating,
    this.hasWordsToReview = false,
    this.onReviewWords,
    this.isCompleted = false,
    this.onMarkCompleted,
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
          // Main control row with repetitions, play controls, and speed
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              children: [
                // Left side - Repetitions
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: RepetitionModeSelector(
                      repetitionMode: repetitionMode,
                      generating: generating,
                    ),
                  ),
                ),
                // Center - Play controls (absolutely centered)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        iconSize: 32,
                        onPressed: audioPlayerService.player.hasPrevious ? () => audioPlayerService.player.seekToPrevious() : null,
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: audioPlayerService.isPlaying,
                        builder: (context, playing, child) {
                          return Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: IconButton(
                              icon: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              iconSize: 36,
                              onPressed: () {
                                audioPlayerService.isPlaying.value = !audioPlayerService.isPlaying.value;
                              },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        iconSize: 32,
                        onPressed: audioPlayerService.player.hasNext ? () => audioPlayerService.player.seekToNext() : null,
                      ),
                    ],
                  ),
                ),
                // Right side - Speed
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: SpeedSelector(
                      playbackSpeed: audioPlayerService.playbackSpeed,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons row (Review Words and Mark as Completed)
          if ((hasWordsToReview && !generating) || !generating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Vocabulary Review Button
                  if (hasWordsToReview && !generating)
                    TextButton.icon(
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
                        'Vocab Review',
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
                    )
                  else
                    const SizedBox.shrink(),

                  // Right side - Mark as Completed Button
                  if (!generating)
                    TextButton.icon(
                      onPressed: isCompleted
                          ? null
                          : () async {
                              // Pause audio before marking as completed
                              if (audioPlayerService.isPlaying.value) {
                                audioPlayerService.isPlaying.value = false;
                              }
                              // Call the completion function
                              onMarkCompleted?.call();
                            },
                      icon: Icon(
                        isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                        size: 16,
                        color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ),
                      label: Text(
                        isCompleted ? 'Completed' : 'Mark as Completed',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCompleted ? Colors.green : Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
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
            'Reps',
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
    return ValueListenableBuilder<double>(
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
    );
  }
}
