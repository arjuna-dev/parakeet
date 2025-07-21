import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/utils/script_generator.dart' show getDocsAndRefsMaps;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart' show WordCard;

class VocabularyService {
  static final VocabularyService _instance = VocabularyService._internal();
  factory VocabularyService() => _instance;
  VocabularyService._internal();

  // Get count of due words that haven't been reviewed today
  static Future<int> getDueWordsCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('VocabularyService: No user found');
        return 0;
      }

      final userId = user.uid;
      debugPrint('VocabularyService: Getting due words for user $userId');

      final userData = await ProfileService.fetchUserData();
      final targetLanguage = userData['target_language'] as String? ?? '';
      debugPrint('VocabularyService: Target language = $targetLanguage');

      if (targetLanguage.isEmpty) {
        debugPrint('VocabularyService: No target language set');
        return 0;
      }

      // Get all words
      final categoriesRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words');
      final categories = await categoriesRef.get();
      final refs = <DocumentReference>[];

      debugPrint('VocabularyService: Found ${categories.docs.length} categories');

      for (var cat in categories.docs) {
        final wordsCol = categoriesRef.doc(cat.id).collection(cat.id);
        final snap = await wordsCol.get();
        debugPrint('VocabularyService: Category ${cat.id} has ${snap.docs.length} words');
        for (var doc in snap.docs) {
          refs.add(doc.reference);
        }
      }

      debugPrint('VocabularyService: Total ${refs.length} word references found');

      final maps = await getDocsAndRefsMaps(refs);
      final docs = maps['docs'] as List<Map<String, dynamic>>;
      final allWords = docs.map(WordCard.fromFirestore).toList();

      debugPrint('VocabularyService: Converted to ${allWords.length} WordCard objects');

      final now = DateTime.now();

      // Filter for words where due date is today or in the past (same logic as vocabulary review screen)
      final dueWords = allWords.where((wordCard) {
        // Check if the word is due (due date <= now)
        final dueDate = wordCard.card.due;
        final isOverdue = dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now);

        // Only consider due date - no lastReview filtering (matches vocabulary review screen)
        return isOverdue;
      }).toList();

      debugPrint('VocabularyService: Found ${dueWords.length} due words');
      return dueWords.length;
    } catch (e, stackTrace) {
      debugPrint('VocabularyService: Error getting due words count: $e');
      debugPrint('VocabularyService: Stack trace: $stackTrace');
      return 0;
    }
  }
}
