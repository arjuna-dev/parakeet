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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
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
              ),
            ),
          ).then((result) {
            if (result == 'reload' && onReload != null) {
              onReload!();
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Section with Gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Icon Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            audioFile.get('title'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 15 : 16,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        Container(
                          width: isSmallScreen ? 32 : 36,
                          height: isSmallScreen ? 32 : 36,
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
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    // Language Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.translate, size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "${(audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)'} → ${audioFile.get('target_language')}",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                color: colorScheme.primary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Section
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stairs, size: 14, color: colorScheme.secondary),
                          const SizedBox(width: 4),
                          Text(
                            "${audioFile.get('language_level')}",
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11 : 12,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    // Bottom Actions Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.arrow_forward_ios,
                          color: colorScheme.primary,
                          size: isSmallScreen ? 16 : 18,
                        ),
                      ],
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
