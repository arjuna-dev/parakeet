import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:parakeet/services/audio_player_manager.dart';

class AudioWaveformWidget extends StatefulWidget {
  const AudioWaveformWidget({super.key});

  @override
  State<AudioWaveformWidget> createState() => _AudioWaveformWidgetState();
}

class _AudioWaveformWidgetState extends State<AudioWaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [];
  ValueNotifier<bool>? _currentPlayingNotifier;
  bool _isPlaying = false;

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
    );
    
    // Start animation initially
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _currentPlayingNotifier?.removeListener(_onPlayingStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onPlayingStateChanged() {
    if (!mounted) return;
    final isPlaying = _currentPlayingNotifier?.value ?? false;
    setState(() {
      _isPlaying = isPlaying;
    });
    _updateAnimationState(isPlaying);
  }

  void _updateAnimationState(bool isPlaying) {
    if (isPlaying) {
      // Stop animation if audio is playing
      _controller.stop();
    } else {
      // Start animation if audio is paused or not present
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final manager = context.watch<AudioPlayerManager>();
    final service = manager.service;
    final isPlayingNotifier = service?.isPlaying;
    
    // Update listener if notifier changed
    if (_currentPlayingNotifier != isPlayingNotifier) {
      _currentPlayingNotifier?.removeListener(_onPlayingStateChanged);
      _currentPlayingNotifier = isPlayingNotifier;
      if (isPlayingNotifier != null) {
        isPlayingNotifier.addListener(_onPlayingStateChanged);
        _isPlaying = isPlayingNotifier.value;
        _updateAnimationState(_isPlaying);
      } else {
        // No active player, start animation
        _isPlaying = false;
        _updateAnimationState(false);
      }
    }
    
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
              // Create a subtle animation effect only when not playing
              final animationValue = _isPlaying 
                  ? 0.0 // No animation when playing
                  : math.sin(
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


