import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WordStats {
  final int learning; // Words with 0 <= scheduledDays < 100 (includes formerly "learned" words)
  final int learned; // Words with 80 <= scheduledDays < 100 (deprecated but kept for compatibility)
  final int mastered; // Words with scheduledDays >= 100
  final int total; // Total words in this category

  WordStats({
    required this.learning,
    required this.learned,
    required this.mastered,
    required this.total,
  });
}

class WordStatsService {
  static Future<WordStats> getCategoryWordStats(
    String categoryName,
    String targetLanguage,
    List<dynamic> categoryWords,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(categoryName).collection(categoryName).get();

      // Convert category words to lowercase for comparison
      final categoryWordsLowercase = categoryWords.map((word) => word.toString().toLowerCase()).toSet();

      int learning = 0;
      int learned = 0;
      int mastered = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String wordInDoc = data['word']?.toString().toLowerCase() ?? '';

        // Only count words that are actually part of this category's word list
        if (categoryWordsLowercase.contains(wordInDoc)) {
          final double scheduledDays = data['scheduledDays'] is int ? (data['scheduledDays'] as int).toDouble() : (data['scheduledDays'] as double? ?? 0.0);

          if (scheduledDays >= 100 || scheduledDays == -1) {
            mastered++;
          } else if (scheduledDays >= 80) {
            learned++;
            // Include previously "learned" words in the learning count for UI display
            learning++;
          } else if (scheduledDays >= 0) {
            learning++;
          }
        }
      }

      return WordStats(
        learning: learning,
        learned: learned,
        mastered: mastered,
        total: learning + mastered, // Only count learning and mastered for total
      );
    } catch (e) {
      print('Error getting category word stats: $e');
      return WordStats(learning: 0, learned: 0, mastered: 0, total: 0);
    }
  }
}
