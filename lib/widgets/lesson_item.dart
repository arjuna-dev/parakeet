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
          document.get('title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 15 : 16,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.translate, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${(document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)'} → ${document.get('target_language')}",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.stairs, size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${document.get('language_level')}",
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
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
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              isFavorite() ? Icons.favorite : Icons.favorite_border,
              color: colorScheme.primary,
              size: isSmallScreen ? 24 : 28,
            ),
            onPressed: () => LibraryService.toggleFavorite(document, model, localFavorites, updateFavorites),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.delete,
                color: colorScheme.error,
                size: isSmallScreen ? 22 : 24,
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
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.primary,
              size: isSmallScreen ? 24 : 28,
            ),
          ],
        ),
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
      ),
    );
  }
}
