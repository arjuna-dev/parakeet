import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/audio_player_service.dart';
import 'package:parakeet/widgets/audio_player_screen/position_data.dart';

class PositionSlider extends StatefulWidget {
  final AudioPlayerService audioPlayerService;
  final Stream<PositionData> positionDataStream;
  final Duration totalDuration;
  final Duration finalTotalDuration;
  final bool isPlaying;
  final int savedPosition;
  final Function(double) findTrackIndexForPosition;
  final AudioPlayer player;
  final Function(int) cumulativeDurationUpTo;
  final Future<void> Function({bool analyticsOn}) pause;
  final VoidCallback onSliderChangeStart;
  final VoidCallback onSliderChangeEnd;

  const PositionSlider({
    Key? key,
    required this.audioPlayerService,
    required this.positionDataStream,
    required this.totalDuration,
    required this.finalTotalDuration,
    required this.isPlaying,
    required this.savedPosition,
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
  Timer? _updateTimer;
  Duration _lastKnownPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Start a timer for smooth position updates
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted && !_isDragging && widget.isPlaying) {
        setState(() {
          _lastKnownPosition = widget.audioPlayerService.getCurrentPosition();
        });
      }
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: widget.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        if (widget.audioPlayerService.playlistInitialized == false && positionData == null) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
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
        } else if (widget.audioPlayerService.playlistInitialized == true && !widget.isPlaying && (_lastKnownPosition.inMilliseconds == 0 || widget.savedPosition == 0)) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Lesson is ready. Click on the Play button!",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        // Use drag value when dragging, otherwise use stream data or saved position
        double currentValue;
        Duration currentPosition;

        if (_isDragging) {
          currentValue = _dragValue;
          currentPosition = Duration(milliseconds: _dragValue.toInt());
        } else if (widget.isPlaying) {
          // Use the most recent position from timer updates for smoother display
          currentPosition = _lastKnownPosition;
          currentValue = currentPosition.inMilliseconds.clamp(0, widget.totalDuration.inMilliseconds).toDouble();
        } else {
          currentValue = widget.savedPosition.clamp(0, widget.totalDuration.inMilliseconds).toDouble();
          currentPosition = Duration(milliseconds: widget.savedPosition);
        }

        return Column(
          children: [
            Slider(
              min: 0.0,
              max: widget.totalDuration.inMilliseconds.toDouble(),
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
                final trackIndex = widget.findTrackIndexForPosition(value);
                final seekPosition = Duration(milliseconds: (value.toInt() - widget.cumulativeDurationUpTo(trackIndex).inMilliseconds).toInt());

                widget.player.seek(seekPosition, index: trackIndex);

                if (!widget.isPlaying) {
                  widget.pause(analyticsOn: false);
                }

                setState(() {
                  _isDragging = false;
                  _lastKnownPosition = Duration(milliseconds: value.toInt());
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
                    widget.finalTotalDuration == Duration.zero ? formatDuration(widget.totalDuration) : formatDuration(widget.finalTotalDuration),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
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
