import 'package:cloud_firestore/cloud_firestore.dart';

class StreakService {
  static final StreakService _instance = StreakService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory StreakService() {
    return _instance;
  }

  StreakService._internal();

  Future<void> recordDailyActivity(String userId) async {
    final today = DateTime.now().toLocal();
    final dateStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    await _firestore.collection('users').doc(userId).collection('activity').doc(dateStr).set({
      'date': dateStr,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<bool>> getLast7DaysActivity(String userId) async {
    final today = DateTime.now().toLocal();
    List<bool> activityList = List.filled(7, false);

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final doc = await _firestore.collection('users').doc(userId).collection('activity').doc(dateStr).get();

      activityList[i] = doc.exists;
    }

    return activityList;
  }

  Future<int> getCurrentStreak(String userId) async {
    final today = DateTime.now().toLocal();
    int streak = 0;
    bool streakBroken = false;

    // Check if today's activity exists
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final todayDoc = await _firestore.collection('users').doc(userId).collection('activity').doc(todayStr).get();

    // Start counting from today if there's activity, otherwise start from yesterday
    int startDay = todayDoc.exists ? 0 : 1;

    for (int i = startDay; !streakBroken; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final doc = await _firestore.collection('users').doc(userId).collection('activity').doc(dateStr).get();

      if (doc.exists) {
        streak++;
      } else {
        streakBroken = true;
      }
    }

    return streak;
  }
}
