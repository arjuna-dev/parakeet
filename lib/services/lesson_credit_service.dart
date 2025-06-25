import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LessonCreditService {
  static const int freeUserCredits = 8;
  static const int premiumUserCredits = 65;

  /// Check if user has enough credits and deduct 1 credit if they do
  /// Returns true if user can generate a lesson, false otherwise
  static Future<bool> checkAndDeductCredit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) {
          // User document doesn't exist, create it with default free credits
          transaction.set(userDocRef, {
            'lesson_credit': freeUserCredits - 1, // Deduct 1 credit for this generation
            'premium': false,
          });
          return true;
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final isPremium = userData['premium'] ?? false;

        // Check if lesson_credit field exists
        if (!userData.containsKey('lesson_credit')) {
          // Initialize credits based on user type
          final initialCredits = isPremium ? premiumUserCredits : freeUserCredits;
          final updateData = <String, dynamic>{
            'lesson_credit': initialCredits - 1, // Deduct 1 credit for this generation
          };

          // Initialize lastCreditReset for premium users
          if (isPremium) {
            updateData['lastCreditReset'] = FieldValue.serverTimestamp();
          }

          transaction.update(userDocRef, updateData);
          return true;
        }

        final currentCredits = userData['lesson_credit'] as int? ?? 0;

        if (currentCredits <= 0) {
          return false; // No credits remaining
        }

        // Deduct 1 credit
        transaction.update(userDocRef, {
          'lesson_credit': currentCredits - 1,
        });

        return true;
      });
    } catch (e) {
      print('Error in checkAndDeductCredit: $e');
      return false;
    }
  }

  /// Get current credit count for a user
  static Future<int> getCurrentCredits() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        return freeUserCredits; // Default for new users
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final isPremium = userData['premium'] ?? false;

      // If lesson_credit field doesn't exist, return default based on user type
      if (!userData.containsKey('lesson_credit')) {
        return isPremium ? premiumUserCredits : freeUserCredits;
      }

      return userData['lesson_credit'] as int? ?? 0;
    } catch (e) {
      print('Error getting current credits: $e');
      return 0;
    }
  }

  /// Initialize credits for a user (for free users without the field)
  static Future<void> initializeCreditsIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final isPremium = userData['premium'] ?? false;

      // Initialize if lesson_credit field doesn't exist
      if (!userData.containsKey('lesson_credit')) {
        final updateData = <String, dynamic>{
          'lesson_credit': isPremium ? premiumUserCredits : freeUserCredits,
        };

        // Initialize lastCreditReset for premium users
        if (isPremium) {
          updateData['lastCreditReset'] = FieldValue.serverTimestamp();
        }

        await userDocRef.update(updateData);
      }
    } catch (e) {
      print('Error initializing credits: $e');
    }
  }

  /// Add credits to user account (for premium subscriptions, etc.)
  static Future<void> addCredits(int creditsToAdd) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.update({
        'lesson_credit': FieldValue.increment(creditsToAdd),
      });
    } catch (e) {
      print('Error adding credits: $e');
    }
  }

  /// Get credit limit based on user type
  static Future<int> getCreditLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return freeUserCredits;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        return freeUserCredits;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final isPremium = userData['premium'] ?? false;

      return isPremium ? premiumUserCredits : freeUserCredits;
    } catch (e) {
      print('Error getting credit limit: $e');
      return freeUserCredits;
    }
  }

  /// Check when the user's credits were last reset (for premium users)
  static Future<DateTime?> getLastCreditReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final lastReset = userData['lastCreditReset'] as Timestamp?;

      return lastReset?.toDate();
    } catch (e) {
      print('Error getting last credit reset: $e');
      return null;
    }
  }

  /// Check if user is eligible for credit reset (premium user with active subscription)
  static Future<bool> isEligibleForCreditReset() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Check if user is premium
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final isPremium = userData['premium'] ?? false;

      if (!isPremium) return false;

      // Check if user has active subscription
      final purchases = await FirebaseFirestore.instance.collection('purchases').where('userId', isEqualTo: user.uid).where('status', isEqualTo: 'ACTIVE').where('type', isEqualTo: 'SUBSCRIPTION').get();

      if (purchases.docs.isEmpty) return false;

      // Check if any subscription is still valid and for subscription products
      final now = DateTime.now();
      for (final doc in purchases.docs) {
        final data = doc.data();
        final expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();
        final productId = data['productId'] as String?;

        if (expiryDate != null && _isSameDateOrAfter(expiryDate, now) && ['1m', '1year'].contains(productId)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error checking credit reset eligibility: $e');
      return false;
    }
  }

  /// Helper method to compare dates only (ignoring time)
  static bool _isSameDateOrAfter(DateTime date1, DateTime date2) {
    final d1 = DateTime(date1.year, date1.month, date1.day);
    final d2 = DateTime(date2.year, date2.month, date2.day);
    return d1.isAfter(d2) || d1.isAtSameMomentAs(d2);
  }

  /// Get the next credit reset date for premium users
  static Future<DateTime?> getNextCreditResetDate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data() as Map<String, dynamic>;
      final lastCreditReset = userData['lastCreditReset'] as Timestamp?;

      // Get user's latest subscription
      final purchases = await FirebaseFirestore.instance
          .collection('purchases')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'SUBSCRIPTION')
          .where('productId', whereIn: ['1m', '1year'])
          .orderBy('purchaseDate', descending: true)
          .limit(1)
          .get();

      if (purchases.docs.isEmpty) return null;

      final latestPurchase = purchases.docs.first.data();
      final purchaseDate = (latestPurchase['purchaseDate'] as Timestamp?)?.toDate();

      if (purchaseDate == null) return null;

      DateTime referenceDate;
      if (lastCreditReset != null) {
        // Use last reset date as reference
        referenceDate = lastCreditReset.toDate();
      } else {
        // Use purchase date as reference for first-time reset
        referenceDate = purchaseDate;
      }

      // Calculate next reset date (one month after reference date)
      final nextReset = DateTime(
        referenceDate.year,
        referenceDate.month + 1,
        referenceDate.day,
        referenceDate.hour,
        referenceDate.minute,
        referenceDate.second,
      );

      return nextReset;
    } catch (e) {
      print('Error getting next credit reset date: $e');
      return null;
    }
  }

  /// Get days until next credit reset
  static Future<int?> getDaysUntilNextReset() async {
    final nextReset = await getNextCreditResetDate();
    if (nextReset == null) return null;

    final now = DateTime.now();
    final difference = nextReset.difference(now);

    return difference.inDays;
  }

  /// Check if user's subscription is expired and handle credit reset
  static Future<void> handleExpiredSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user has any expired subscriptions
      final purchases = await FirebaseFirestore.instance.collection('purchases').where('userId', isEqualTo: user.uid).where('type', isEqualTo: 'SUBSCRIPTION').where('productId', whereIn: ['1m', '1year']).get();

      if (purchases.docs.isEmpty) return;

      final now = DateTime.now();
      bool hasActiveSubscription = false;

      for (final doc in purchases.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final expiryDate = (data['expiryDate'] as Timestamp?)?.toDate();

        if (status == 'ACTIVE' && expiryDate != null && _isSameDateOrAfter(expiryDate, now)) {
          hasActiveSubscription = true;
          break;
        }
      }

      // If no active subscription, reset credits to 0
      if (!hasActiveSubscription) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        await userDocRef.update({
          'lesson_credit': 0,
          'premium': false,
        });
      }
    } catch (e) {
      print('Error handling expired subscription: $e');
    }
  }

  /// Handle when user becomes premium (sets credits to 65 and initializes reset date)
  static Future<void> handlePremiumActivation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.update({
        'premium': true,
        'lesson_credit': 65,
        'lastCreditReset': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error handling premium activation: $e');
    }
  }
}
