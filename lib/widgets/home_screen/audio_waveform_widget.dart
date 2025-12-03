import 'package:flutter/material.dart';
import 'dart:math' as math;

class AudioWaveformWidget extends StatefulWidget {
  const AudioWaveformWidget({super.key});

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [];

  @override
  void initState() {
    super.initState();
    
    // Generate random heights for the waveform bars
    final random = math.Random();
    for (int i = 0; i < 40; i++) {
      _heights.add(10 + random.nextDouble() * 30);
    }
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 60,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_heights.length, (index) {
              // Create a subtle animation effect
              final animationValue = math.sin(
                (_controller.value * 2 * math.pi) + (index * 0.2),
              );
              final animatedHeight = _heights[index] * (0.7 + 0.3 * animationValue.abs());
              
              return Container(
                width: 3,
                height: animatedHeight.clamp(10.0, 50.0),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}


