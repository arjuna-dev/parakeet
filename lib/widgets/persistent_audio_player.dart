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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Thumbnail / Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note,
                color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),

          // Title
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
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  lesson.category,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Controls
          IconButton(
            icon: ValueListenableBuilder<bool>(
              valueListenable:
                  manager.service?.isPlaying ?? ValueNotifier(false),
              builder: (context, isPlaying, _) {
                return Icon(isPlaying ? Icons.pause : Icons.play_arrow);
              },
            ),
            onPressed: () {
              final service = manager.service;
              if (service != null) {
                service.isPlaying.value = !service.isPlaying.value;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              manager.close();
            },
          ),
        ],
      ),
    );
  }
}

class _ExpandedPlayerWrapper extends StatelessWidget {
  final AudioPlayerManager manager;

  const _ExpandedPlayerWrapper({required this.manager});

  @override
  Widget build(BuildContext context) {
    // We need to wrap the AudioPlayerScreen or modify it to support being embedded.
    // For now, let's assume we can pass the existing service or just use the parameters.
    // Since AudioPlayerScreen creates its own service, we need to REFACTOR AudioPlayerScreen first.
    // But for this step, I'll put a placeholder or try to use it as is (which will double-init service).

    // Ideally, AudioPlayerScreen should accept an existing service.
    // I will modify AudioPlayerScreen to accept 'audioPlayerService' as an optional parameter.

    final lesson = manager.currentLesson!;

    return Stack(
      children: [
        // The actual player screen
        AudioPlayerScreen(
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
          // We will add this parameter to AudioPlayerScreen
          existingService: manager.service,
        ),

        // Collapse button (top right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down,
                size: 32, color: Colors.white), // Assuming dark bg or contrast
            onPressed: () {
              manager.collapse();
            },
          ),
        ),
      ],
    );
  }
}
