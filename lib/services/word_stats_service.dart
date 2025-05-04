import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WordStats {
  final int learning; // Words with 0 <= scheduledDays < 80
  final int learned; // Words with 80 <= scheduledDays < 100
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
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(categoryName).collection(categoryName).get();

      int learning = 0;
      int learned = 0;
      int mastered = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double scheduledDays = data['scheduledDays'] is int ? (data['scheduledDays'] as int).toDouble() : (data['scheduledDays'] as double? ?? 0.0);

        if (scheduledDays >= 100) {
          mastered++;
        } else if (scheduledDays >= 80) {
          learned++;
        } else if (scheduledDays >= 0) {
          learning++;
        }
      }

      return WordStats(
        learning: learning,
        learned: learned,
        mastered: mastered,
        total: snapshot.docs.length,
      );
    } catch (e) {
      print('Error getting category word stats: $e');
      return WordStats(learning: 0, learned: 0, mastered: 0, total: 0);
    }
  }
}
