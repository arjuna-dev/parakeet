import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/audio_player_manager.dart';
import 'package:parakeet/screens/audio_player_screen.dart';

class PersistentAudioPlayer extends StatelessWidget {
  const PersistentAudioPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AudioPlayerManager>();

    // If not visible, return empty widget
    if (!manager.isVisible) return const SizedBox.shrink();

    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    // Standard bottom nav height + padding used in BottomMenuBar
    final double bottomNavHeight =
        kBottomNavigationBarHeight + 16 + bottomPadding;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      // If expanded, cover everything (bottom: 0).
      // If mini, sit above bottom nav (bottom: bottomNavHeight).
      bottom: manager.isExpanded ? 0 : bottomNavHeight,
      // If expanded, go to top (top: 0).
      // If mini, height is fixed (top: null).
      top: manager.isExpanded ? 0 : null,
      height: manager.isExpanded ? null : 64, // Mini player height
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: manager.isExpanded
            ? BorderRadius.zero
            : const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          decoration: manager.isExpanded
              ? null
              : BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                    width: 2,
                  ),
                ),
        child: GestureDetector(
          onTap: () {
            if (!manager.isExpanded) {
              manager.expand();
            }
          },
          // Use a Stack to crossfade between Mini and Expanded views
          child: Stack(
            children: [
              // Mini Player
              AnimatedOpacity(
                opacity: manager.isExpanded ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: manager.isExpanded,
                  child: _MiniPlayer(manager: manager),
                ),
              ),

              // Expanded Player
              AnimatedOpacity(
                opacity: manager.isExpanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !manager.isExpanded,
                  child: _ExpandedPlayerWrapper(manager: manager),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  final AudioPlayerManager manager;

  const _MiniPlayer({required this.manager});

  @override
  Widget build(BuildContext context) {
    final lesson = manager.currentLesson;
    if (lesson == null) return const SizedBox.shrink();

    final service = manager.service;
    final isPlayingNotifier = service?.isPlaying ?? ValueNotifier(false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
                // Audio waveform icon / visual indicator
                ValueListenableBuilder<bool>(
                  valueListenable: isPlayingNotifier,
                  builder: (context, isPlaying, _) {
                    return Container(
                      width: 48,
                      height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPlaying
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          width: isPlaying ? 2 : 1,
                        ),
            ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Animated waveform when playing
                          if (isPlaying)
                            _AnimatedWaveform(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          // Static icon when paused
                          if (!isPlaying)
                            Icon(
                              Icons.graphic_eq,
                              color: Theme.of(context).colorScheme.primary,
                              size: 24,
                            ),
                        ],
                      ),
                    );
                  },
          ),
          const SizedBox(width: 12),

                // Title and category
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                      const SizedBox(height: 2),
                Text(
                  lesson.category,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

                // Play/Pause button - more prominent
                ValueListenableBuilder<bool>(
                  valueListenable: isPlayingNotifier,
              builder: (context, isPlaying, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
            ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
              if (service != null) {
                service.isPlaying.value = !service.isPlaying.value;
              }
            },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            child: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Close button
          IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
            onPressed: () {
              manager.close();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildWaveformIcon(BuildContext context, bool isPlaying) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Animated waveform when playing
        if (isPlaying)
          _AnimatedWaveform(
            color: Theme.of(context).colorScheme.primary,
          ),
        // Static icon when paused
        if (!isPlaying)
          Icon(
            Icons.graphic_eq,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
      ],
    );
  }
}

// Animated waveform widget
class _AnimatedWaveform extends StatefulWidget {
  final Color color;

  const _AnimatedWaveform({required this.color});

  @override
  State<_AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<_AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(24, 24),
          painter: _WaveformPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

// Custom painter for animated waveform
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const barWidth = 3.0;
    const spacing = 2.5;
    final maxHeight = size.height * 0.7;

    // Draw animated waveform bars
    for (int i = 0; i < 4; i++) {
      final x = (i * (barWidth + spacing)) + barWidth / 2;
      final animationOffset = (i * 0.25) % 1.0;
      final waveProgress = ((progress + animationOffset) % 1.0);
      
      // Create wave effect using sine
      final height = (math.sin(waveProgress * 2 * math.pi) * 0.5 + 0.5) * maxHeight;
      final barHeight = height.clamp(4.0, maxHeight);
      
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ExpandedPlayerWrapper extends StatefulWidget {
  final AudioPlayerManager manager;

  const _ExpandedPlayerWrapper({required this.manager});

  @override
  State<_ExpandedPlayerWrapper> createState() => _ExpandedPlayerWrapperState();
}

class _ExpandedPlayerWrapperState extends State<_ExpandedPlayerWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final lesson = widget.manager.currentLesson;
    if (lesson == null) return const SizedBox.shrink();

    // Use a unique key based on documentID to preserve widget state
    // This ensures the AudioPlayerScreen widget is NOT recreated on rebuild
    return Stack(
      children: [
        KeyedSubtree(
          key: ValueKey('audio_player_${lesson.documentID}'),
          child: AudioPlayerScreen(
            documentID: lesson.documentID,
            dialogue: lesson.dialogue ?? [],
            category: lesson.category,
            targetLanguage: lesson.targetLanguage,
            nativeLanguage: lesson.nativeLanguage,
            languageLevel: lesson.languageLevel,
            userID: lesson.userID,
            title: lesson.title,
            scriptDocumentId: lesson.scriptDocumentId,
            generating: lesson.generating,
            wordsToRepeat: lesson.wordsToRepeat ?? [],
            numberOfTurns: lesson.numberOfTurns,
            existingService: widget.manager.service,
            isEmbedded: true,
          ),
        ),
      ],
    );
  }
}
