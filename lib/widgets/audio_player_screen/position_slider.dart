import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/widgets/audio_player_screen/position_data.dart';

class PositionSlider extends StatelessWidget {
  final Stream<PositionData> positionDataStream;
  final Duration totalDuration;
  final Duration finalTotalDuration;
  final bool isPlaying;
  final int savedPosition;
  final Function(double) findTrackIndexForPosition;
  final AudioPlayer player;
  final Function(int) cumulativeDurationUpTo;
  final Future<void> Function({bool analyticsOn}) pause;
  final VoidCallback onSliderChangeStart; // Pf506
  final VoidCallback onSliderChangeEnd; // Pf506

  const PositionSlider({
    Key? key,
    required this.positionDataStream,
    required this.totalDuration,
    required this.finalTotalDuration,
    required this.isPlaying,
    required this.savedPosition,
    required this.findTrackIndexForPosition,
    required this.player,
    required this.cumulativeDurationUpTo,
    required this.pause,
    required this.onSliderChangeStart, // Pf506
    required this.onSliderChangeEnd, // Pf506
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data;
        if (positionData == null) return const CircularProgressIndicator();
        return Column(
          children: [
            Slider(
              min: 0.0,
              max: totalDuration.inMilliseconds.toDouble(),
              value: isPlaying ? positionData.cumulativePosition.inMilliseconds.clamp(0, totalDuration.inMilliseconds).toDouble() : savedPosition.clamp(0, totalDuration.inMilliseconds).toDouble(),
              onChanged: (value) {
                final trackIndex = findTrackIndexForPosition(value);
                player.seek(Duration(milliseconds: (value.toInt() - cumulativeDurationUpTo(trackIndex).inMilliseconds).toInt()), index: trackIndex);
                if (!isPlaying) {
                  pause(analyticsOn: false);
                }
              },
              onChangeStart: (value) {
                onSliderChangeStart(); // Pf506
              },
              onChangeEnd: (value) {
                onSliderChangeEnd(); // Pf506
              },
            ),
            Text(
              finalTotalDuration == Duration.zero
                  ? formatDuration(isPlaying ? positionData.cumulativePosition : Duration(milliseconds: savedPosition))
                  : "${formatDuration(isPlaying ? positionData.cumulativePosition : Duration(milliseconds: savedPosition))} / ${formatDuration(finalTotalDuration)}",
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
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
