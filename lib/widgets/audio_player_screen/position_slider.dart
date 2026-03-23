import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/widgets/audio_player_screen/position_data.dart';

class PositionSlider extends StatefulWidget {
  final AudioPlayerService audioPlayerService;
  final Function(double) findTrackIndexForPosition;
  final AudioPlayer player;
  final Function(int) cumulativeDurationUpTo;
  final Future<void> Function({bool analyticsOn}) pause;
  final VoidCallback onSliderChangeStart;
  final VoidCallback onSliderChangeEnd;

  const PositionSlider({
    Key? key,
    required this.audioPlayerService,
    required this.findTrackIndexForPosition,
    required this.player,
    required this.cumulativeDurationUpTo,
    required this.pause,
    required this.onSliderChangeStart,
    required this.onSliderChangeEnd,
  }) : super(key: key);

  @override
  State<PositionSlider> createState() => _PositionSliderState();
}

class _PositionSliderState extends State<PositionSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    // Do not rely only on StreamBuilder rebuilds: playlistInitialized can become
    // true before positionDataStream emits (buffering). Parent setState still
    // rebuilds this widget so we re-read playlistInitialized here.
    final playlistReady = widget.audioPlayerService.playlistInitialized;

    return StreamBuilder<PositionData>(
      stream: widget.audioPlayerService.positionDataStream,
      builder: (context, snapshot) {
        if (!playlistReady) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Loading lesson...",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        return ValueListenableBuilder<bool>(
          valueListenable: widget.audioPlayerService.isPlaying,
          builder: (context, isPlaying, _) {
            // Always derive from the player + track offsets (same as position stream).
            // Avoids prefs, stale parent props, and per-file-only glitches.
            final liveCumulative =
                widget.audioPlayerService.getCurrentPosition();

            if (playlistReady &&
                !isPlaying &&
                liveCumulative.inMilliseconds == 0) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Lesson is ready. Click on the Play button!",
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    CustomPaint(
                      size: const Size(20, 10),
                      painter: TrianglePainter(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ValueListenableBuilder<Duration>(
              valueListenable: widget.audioPlayerService.totalDuration,
              builder: (context, totalDuration, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: widget.audioPlayerService.finalTotalDuration,
                  builder: (context, finalTotalDuration, _) {
                    // One source for slider range + end label (they can diverge briefly
                    // when only one notifier updates).
                    final effectiveTotalMs = totalDuration.inMilliseconds >
                            finalTotalDuration.inMilliseconds
                        ? totalDuration.inMilliseconds
                        : finalTotalDuration.inMilliseconds;
                    final sliderMaxMs =
                        effectiveTotalMs > 0 ? effectiveTotalMs : 1000;

                    double currentValue;
                    Duration currentPosition;

                    if (_isDragging) {
                      currentValue = _dragValue;
                      currentPosition =
                          Duration(milliseconds: _dragValue.toInt());
                    } else {
                      currentPosition = liveCumulative;
                      currentValue = currentPosition.inMilliseconds
                          .clamp(0, sliderMaxMs)
                          .toDouble();
                    }

                    return Column(
                      children: [
                        Slider(
                          min: 0.0,
                          max: sliderMaxMs.toDouble(),
                          value: currentValue,
                          onChanged: (value) {
                            setState(() {
                              _dragValue = value;
                            });
                          },
                          onChangeStart: (value) {
                            setState(() {
                              _isDragging = true;
                              _dragValue = value;
                            });
                            widget.onSliderChangeStart();
                          },
                          onChangeEnd: (value) {
                            final trackIndex =
                                widget.findTrackIndexForPosition(value);
                            final seekPosition = Duration(
                                milliseconds: (value.toInt() -
                                        widget
                                            .cumulativeDurationUpTo(trackIndex)
                                            .inMilliseconds)
                                    .toInt());

                            widget.player.seek(seekPosition, index: trackIndex);

                            if (!isPlaying) {
                              widget.pause(analyticsOn: false);
                            }

                            setState(() {
                              _isDragging = false;
                            });
                            widget.onSliderChangeEnd();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                formatDuration(currentPosition),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                () {
                                  if (effectiveTotalMs <= 0) {
                                    return '--:--';
                                  }
                                  return formatDuration(
                                      Duration(milliseconds: effectiveTotalMs));
                                }(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
