import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class EmptyLibraryView extends StatelessWidget {
  final bool isSmallScreen;

  const EmptyLibraryView({
    Key? key,
    required this.isSmallScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: isSmallScreen ? 32 : 48,
            color: colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 14 : 16,
              ),
              children: <TextSpan>[
                const TextSpan(text: 'Your library is empty. '),
                TextSpan(
                  text: 'Create your first lesson 🎵',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacementNamed(context, '/create_lesson');
                    },
                ),
                const TextSpan(text: ' to fill it with your audio lessons!'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
