import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:parakeet/services/background_audio_service.dart';

class BackgroundAudioInfo extends StatelessWidget {
  const BackgroundAudioInfo({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!BackgroundAudioService.isInitialized) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<MediaItem?>(
      stream: BackgroundAudioService.audioHandler?.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(5.0),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.music_note,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mediaItem.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (mediaItem.genre != null)
                      Text(
                        mediaItem.genre!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
