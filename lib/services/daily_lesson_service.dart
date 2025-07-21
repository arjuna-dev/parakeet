import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DailyLessonService {
  static const int freeUserDailyLimit = 2;
  static const int premiumUserDailyLimit = 10; // Premium users get more lessons per day

  /// Check if user can generate a lesson and increment daily count
  /// Returns true if user can generate a lesson, false otherwise
  static Future<bool> checkAndIncrementDaily() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('api_call_count').doc('first_API_calls');

    try {
      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);
        final today = _getTodayString();

        Map<String, dynamic> data;
        if (!userDoc.exists) {
          // Create new document with first call
          data = {
            'last_call_date': today,
            'call_count': 1,
          };
          transaction.set(userDocRef, data);
          return true;
        }

        data = userDoc.data() as Map<String, dynamic>;
        final lastCallDate = data['last_call_date'] as String?;
        int currentCount = data['call_count'] as int? ?? 0;

        // Reset count if it's a new day
        if (lastCallDate != today) {
          currentCount = 0;
        }

        // Check if user has reached daily limit
        final dailyLimit = await _getUserDailyLimit();
        if (currentCount >= dailyLimit) {
          return false; // Daily limit reached
        }

        // Increment count
        transaction.update(userDocRef, {
          'last_call_date': today,
          'call_count': currentCount + 1,
        });

        return true;
      });
    } catch (e) {
      print('Error in checkAndIncrementDaily: $e');
      return false;
    }
  }

  /// Get current daily usage for a user
  static Future<int> getCurrentDailyUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('api_call_count').doc('first_API_calls').get();

      if (!userDoc.exists) {
        return 0; // No usage yet
      }

      final data = userDoc.data() as Map<String, dynamic>;
      final lastCallDate = data['last_call_date'] as String?;
      final today = _getTodayString();

      // If last call was not today, usage is 0
      if (lastCallDate != today) {
        return 0;
      }

      return data['call_count'] as int? ?? 0;
    } catch (e) {
      print('Error getting current daily usage: $e');
      return 0;
    }
  }

  /// Get daily limit based on user type
  static Future<int> getDailyLimit() async {
    return await _getUserDailyLimit();
  }

  /// Get remaining lessons for today
  static Future<int> getRemainingLessons() async {
    final currentUsage = await getCurrentDailyUsage();
    final dailyLimit = await getDailyLimit();
    return (dailyLimit - currentUsage).clamp(0, dailyLimit);
  }

  /// Check if user is premium
  static Future<bool> _isUserPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['premium'] ?? false;
    } catch (e) {
      print('Error checking premium status: $e');
      return false;
    }
  }

  /// Get user's daily limit based on premium status
  static Future<int> _getUserDailyLimit() async {
    final isPremium = await _isUserPremium();
    return isPremium ? premiumUserDailyLimit : freeUserDailyLimit;
  }

  /// Get today's date as string (YYYY-MM-DD format)
  static String _getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  /// Get progress data for UI display
  static Future<Map<String, dynamic>> getDailyProgressData() async {
    try {
      final currentUsage = await getCurrentDailyUsage();
      final dailyLimit = await getDailyLimit();
      final isPremium = await _isUserPremium();
      final remaining = (dailyLimit - currentUsage).clamp(0, dailyLimit);

      return {
        'used': currentUsage,
        'remaining': remaining,
        'limit': dailyLimit,
        'isPremium': isPremium,
      };
    } catch (e) {
      print('Error getting daily progress data: $e');
      return {
        'used': 0,
        'remaining': freeUserDailyLimit,
        'limit': freeUserDailyLimit,
        'isPremium': false,
      };
    }
  }

  /// Initialize daily usage for a user if needed
  static Future<void> initializeDailyUsageIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('api_call_count').doc('first_API_calls');
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        final today = _getTodayString();
        await userDocRef.set({
          'last_call_date': today,
          'call_count': 0,
        });
      }
    } catch (e) {
      print('Error initializing daily usage: $e');
    }
  }
}
