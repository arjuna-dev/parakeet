import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/screens/audio_player_screen.dart';

class LessonCard extends StatelessWidget {
  final DocumentSnapshot audioFile;
  final IconData leadingIcon;
  final VoidCallback? onReload;
  final bool isSmallScreen;

  const LessonCard({
    Key? key,
    required this.audioFile,
    required this.leadingIcon,
    this.onReload,
    required this.isSmallScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 12,
        ),
        title: Text(
          audioFile.get('title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 15 : 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.translate, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${(audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)'} → ${audioFile.get('target_language')}",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.stairs, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  "${audioFile.get('language_level')}",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        leading: Container(
          width: isSmallScreen ? 40 : 48,
          height: isSmallScreen ? 40 : 48,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            leadingIcon,
            color: colorScheme.primary,
            size: isSmallScreen ? 24 : 28,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.primary,
          size: isSmallScreen ? 24 : 28,
        ),
        onTap: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerScreen(
                documentID: audioFile.reference.parent.parent!.id,
                dialogue: audioFile.get('dialogue'),
                targetLanguage: audioFile.get('target_language'),
                nativeLanguage: (audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)',
                languageLevel: audioFile.get('language_level'),
                userID: FirebaseAuth.instance.currentUser!.uid,
                title: audioFile.get('title'),
                scriptDocumentId: audioFile.id,
                generating: false,
                wordsToRepeat: audioFile.get('words_to_repeat'),
              ),
            ),
          ).then((result) {
            if (result == 'reload' && onReload != null) {
              onReload!();
            }
          });
        },
      ),
    );
  }
}
