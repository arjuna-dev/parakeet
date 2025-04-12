import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/services/library_service.dart';

class LessonItem extends StatelessWidget {
  final DocumentSnapshot document;
  final String category;
  final bool isSmallScreen;
  final HomeScreenModel model;
  final Map<String, bool> localFavorites;
  final Function(Map<String, bool>) updateFavorites;
  final Function(DocumentSnapshot) onDelete;

  const LessonItem({
    Key? key,
    required this.document,
    required this.category,
    required this.isSmallScreen,
    required this.model,
    required this.localFavorites,
    required this.updateFavorites,
    required this.onDelete,
  }) : super(key: key);

  bool isFavorite() {
    String parentId = document.reference.parent.parent!.id;
    String docId = document.reference.id;
    String key = '$parentId-$docId';
    return localFavorites[key] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
      child: InkWell(
        onTap: () async {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerScreen(
                category: category,
                documentID: document.reference.parent.parent!.id,
                dialogue: document.get('dialogue'),
                targetLanguage: document.get('target_language'),
                nativeLanguage: (document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)',
                languageLevel: document.get('language_level'),
                userID: FirebaseAuth.instance.currentUser!.uid,
                title: document.get('title'),
                generating: false,
                wordsToRepeat: document.get('words_to_repeat'),
                scriptDocumentId: document.id,
              ),
            ),
          );
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
                    // Title and Favorite Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            document.get('title'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 15 : 16,
                              color: colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isFavorite() ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite() ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            size: isSmallScreen ? 20 : 24,
                          ),
                          onPressed: () => LibraryService.toggleFavorite(document, model, localFavorites, updateFavorites),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
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
                              "${(document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)'} → ${document.get('target_language')}",
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
                            "${document.get('language_level')}",
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                            size: isSmallScreen ? 20 : 22,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Confirmation'),
                                  content: const Text('Are you sure you want to delete this audio?'),
                                  actions: <Widget>[
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: colorScheme.error),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        onDelete(document);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
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
