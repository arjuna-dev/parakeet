import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/widgets/home_screen/empty_state_view.dart';
import 'package:parakeet/widgets/home_screen/lesson_card.dart';

class HomeScreenService {
  static Widget buildNowPlayingList(BuildContext context, HomeScreenModel model, VoidCallback onReload) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return model.nowPlayingFiles.isEmpty
        ? EmptyStateView(
            icon: Icons.headphones_outlined,
            message: 'Start playing audio lessons to see them here! 🎧',
            additionalWidget: null,
            isSmallScreen: isSmallScreen,
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
            itemCount: model.nowPlayingFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.nowPlayingFiles[index];
              return LessonCard(
                audioFile: audioFile,
                leadingIcon: index == 0 ? Icons.play_circle : Icons.history,
                onReload: onReload,
                isSmallScreen: isSmallScreen,
              );
            },
          );
  }

  static Widget buildFavoritesList(BuildContext context, HomeScreenModel model, VoidCallback onReload) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return model.favoriteAudioFiles.isEmpty
        ? EmptyStateView(
            icon: Icons.favorite_outline,
            message: 'Nothing here yet 😅.',
            additionalWidget: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Go to library',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushReplacementNamed(context, '/library');
                      },
                  ),
                  const TextSpan(text: ' to add audio lessons to your favorite list!'),
                ],
              ),
            ),
            isSmallScreen: isSmallScreen,
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
            itemCount: model.favoriteAudioFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.favoriteAudioFiles[index];
              return LessonCard(
                audioFile: audioFile,
                leadingIcon: Icons.favorite,
                onReload: onReload,
                isSmallScreen: isSmallScreen,
              );
            },
          );
  }
}
