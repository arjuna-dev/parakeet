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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 6 : 8),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
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
                  numberOfTurns: 4,
                ),
              ),
            ).then((result) {
              if (result == 'reload' && onReload != null) {
                onReload!();
              }
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.secondary.withOpacity(0.15),
                    ],
                  ),
                ),
                padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and tags column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            audioFile.get('title'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 16 : 18,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          // Tags row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Language tag
                              Chip(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                padding: EdgeInsets.zero,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.translate, size: 14, color: colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${(audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)'} → ${audioFile.get('target_language')}",
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        color: colorScheme.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                                backgroundColor: colorScheme.primary.withOpacity(0.1),
                                visualDensity: VisualDensity.compact,
                              ),
                              // Level tag
                              Chip(
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                padding: EdgeInsets.zero,
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.stairs, size: 14, color: colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      audioFile.get('language_level'),
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 11 : 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.7),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Icon container
                    Container(
                      width: isSmallScreen ? 36 : 40,
                      height: isSmallScreen ? 36 : 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        leadingIcon,
                        color: colorScheme.primary,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ),
                  ],
                ),
              ),
              // Footer with action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
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
                              numberOfTurns: 4,
                            ),
                          ),
                        ).then((result) {
                          if (result == 'reload' && onReload != null) {
                            onReload!();
                          }
                        });
                      },
                      icon: Icon(
                        Icons.play_circle_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: const Text(
                        'Start Lesson',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
