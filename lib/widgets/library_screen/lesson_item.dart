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
                            document.get('title'),
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
                                      "${(document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)'} → ${document.get('target_language')}",
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
                                    Icon(Icons.stairs, size: 14, color: colorScheme.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      document.get('language_level'),
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
                    // Favorite button
                    IconButton(
                      icon: Icon(
                        isFavorite() ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite() ? colorScheme.error : colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () => LibraryService.toggleFavorite(document, model, localFavorites, updateFavorites),
                    ),
                  ],
                ),
              ),
              // Footer with actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Delete button
                    TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Confirmation'),
                              content: const Text('Are you sure you want to delete this lesson?'),
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
                      icon: Icon(Icons.delete_outline, color: colorScheme.error),
                      label: Text('Delete', style: TextStyle(color: colorScheme.error)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    // Play button
                    OutlinedButton.icon(
                      onPressed: () async {
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
                      icon: Icon(
                        Icons.play_circle_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      label: const Text(
                        'Play Lesson',
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
