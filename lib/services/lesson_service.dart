import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/lesson_constants.dart';

import 'package:parakeet/screens/store_view.dart';
import 'package:parakeet/services/daily_lesson_service.dart';
import 'package:parakeet/services/recent_lesson_topics_service.dart';
import 'package:parakeet/utils/script_generator.dart'
    show storeKeywordTranslations, clearKeywordTranslations;
import 'package:provider/provider.dart';
import 'package:parakeet/services/audio_player_manager.dart';

class LessonService {
  /// Shows a snackbar without throwing if [context] was deactivated after an await.
  static void safeShowSnackBar(BuildContext context, SnackBar snackBar) {
    if (!context.mounted) return;
    try {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(snackBar);
    } catch (_) {
      // Context may be inactive while a Future completes (e.g. user navigated away).
    }
  }

  /// Concurrent lesson-generation slots (second API / TTS). Enforced atomically in
  /// [tryReserveActiveCreationSlot]; keep aligned with TTS quota (~500 RPM project limit).
  static const int activeCreationAllowed = 12;

  /// Drop queue entries older than this so stuck jobs free a slot (server also removes on completion).
  static const int activeCreationStaleMinutes = 45;
  static const int freeAPILimit = 2;
  static const int premiumAPILimit = 10;

  // Function to show premium dialog when credits are exhausted
  static Future<bool> showPremiumDialog(BuildContext context) async {
    final shouldEnablePremium = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface,
                  colorScheme.surfaceContainer.withOpacity(0.8),
                ],
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Premium Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.amber.shade700,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Unlock Premium',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'You\'re out of daily lessons',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // Features
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Generate 10 lessons per day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.speaker_group,
                              color: colorScheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Access to premium voices',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Column(
                    children: [
                      // Primary Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, false);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const StoreView()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: colorScheme.primary.withOpacity(0.3),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Premium',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Secondary Button
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Maybe Later',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    return shouldEnablePremium ?? false;
  }

  // Function to check credit limits (server will handle deduction)
  static Future<bool> checkAndDeductCredit(BuildContext context) async {
    // Check daily limit, don't deduct yet (server will handle deduction)
    final remainingLessons = await DailyLessonService.getRemainingLessons();

    if (remainingLessons <= 0) {
      // No daily lessons remaining, show dialog
      final shouldEnablePremium = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainer.withOpacity(0.8),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Unlock Premium',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'You\'ve used all your credits',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Features
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Generate 65x lessons every month',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Access to all categories',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Column(
                      children: [
                        // Primary Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const StoreView()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: colorScheme.primary.withOpacity(0.3),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Premium',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Secondary Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Maybe Later',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      return shouldEnablePremium ?? false;
    }
    // Concurrent slots are enforced atomically when starting a lesson (tryReserveActiveCreationSlot).

    return true;
  }

  // Function to check premium status and API limits
  static Future<bool> checkPremiumAndAPILimits(BuildContext context) async {
    // Check premium status
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    final isPremium = userDoc.data()?['premium'] ?? false;

    final apiCalls = await countAPIcallsByUser();
    // Free user limit
    if (!isPremium) {
      if (apiCalls >= freeAPILimit) {
        final shouldEnablePremium = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainer.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium Icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Unlock Premium',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'You\'ve reached the free limit',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Features
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Generate up to 10 lessons per day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.all_inclusive,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Access to all categories',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons
                      Column(
                        children: [
                          // Primary Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context, false);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => const StoreView()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor:
                                    colorScheme.primary.withOpacity(0.3),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Get Premium',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Secondary Button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.onSurfaceVariant,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Maybe Later',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // If dialog was dismissed or user chose not to upgrade
        if (shouldEnablePremium != true) {
          return false;
        }
      }
    } else {
      // Premium user limit
      if (apiCalls >= premiumAPILimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unfortunately, you have reached the maximum number of creation for today 🙃. Please come back tomorrow.'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
    }

    // Concurrent slots are enforced atomically when starting a lesson (tryReserveActiveCreationSlot).

    return true;
  }

  /// Normalizes Firestore users array: drops stale entries, dedupes by (userId, documentId).
  static List<Map<String, dynamic>> _normalizeActiveCreationUsers(
      DocumentSnapshot snap) {
    if (!snap.exists) return [];
    final raw = snap.data();
    if (raw is! Map<String, dynamic>) return [];
    final list = raw['users'];
    if (list is! List) return [];
    final now = DateTime.now();
    final List<Map<String, dynamic>> rows = [];
    for (final item in list) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final ts = m['timestamp'];
      if (ts is Timestamp) {
        if (now.difference(ts.toDate()).inMinutes > activeCreationStaleMinutes) {
          continue;
        }
      }
      rows.add(m);
    }
    final Map<String, Map<String, dynamic>> byKey = {};
    for (final m in rows) {
      final uid = m['userId']?.toString() ?? '';
      final did = m['documentId']?.toString() ?? '';
      final key = '$uid|$did';
      final existing = byKey[key];
      if (existing == null) {
        byKey[key] = m;
        continue;
      }
      final t1 = existing['timestamp'];
      final t2 = m['timestamp'];
      if (t1 is Timestamp && t2 is Timestamp) {
        if (t2.toDate().isAfter(t1.toDate())) {
          byKey[key] = m;
        }
      } else {
        byKey[key] = m;
      }
    }
    return byKey.values.toList();
  }

  /// Atomically reserve a slot if under the cap. Call once when starting generation (before first API).
  static Future<bool> tryReserveActiveCreationSlot(
      String userId, String documentId) async {
    final docRef = FirebaseFirestore.instance
        .collection('active_creation')
        .doc('active_creation');

    Future<bool> runOnce() {
      return FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snap = await transaction.get(docRef);
          var users = _normalizeActiveCreationUsers(snap);

          final existingIdx = users.indexWhere((u) =>
              u['userId'] == userId && u['documentId'] == documentId);
          // Use [Timestamp.now] here, not [FieldValue.serverTimestamp]: nested
          // serverTimestamp in transaction writes breaks Firestore web interop
          // ("Attempting to box non-Dart object") and blocks lesson start on web.
          final ts = Timestamp.now();
          if (existingIdx >= 0) {
            users[existingIdx] = {
              'userId': userId,
              'documentId': documentId,
              'timestamp': ts,
            };
            transaction.set(docRef, {'users': users}, SetOptions(merge: true));
            return true;
          }
          if (users.length >= activeCreationAllowed) {
            return false;
          }
          users.add({
            'userId': userId,
            'documentId': documentId,
            'timestamp': ts,
          });
          transaction.set(docRef, {'users': users}, SetOptions(merge: true));
          return true;
        },
        timeout: const Duration(seconds: 60),
        maxAttempts: 5,
      );
    }

    const maxOuterAttempts = 3;
    for (var attempt = 0; attempt < maxOuterAttempts; attempt++) {
      try {
        return await runOnce().timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            throw TimeoutException('active_creation transaction');
          },
        );
      } catch (e) {
        print(
            'tryReserveActiveCreationSlot (attempt ${attempt + 1}/$maxOuterAttempts): $e');
        if (attempt == maxOuterAttempts - 1) {
          return false;
        }
        await Future<void>.delayed(
            Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return false;
  }

  /// Remove one slot (client leaving early or error path). Safe if already removed.
  static Future<void> releaseActiveCreationSlot(
      String userId, String documentId) async {
    final docRef = FirebaseFirestore.instance
        .collection('active_creation')
        .doc('active_creation');
    try {
      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final snap = await transaction.get(docRef);
          var users = _normalizeActiveCreationUsers(snap);
          users.removeWhere((u) =>
              u['userId'] == userId && u['documentId'] == documentId);
          transaction.set(docRef, {'users': users}, SetOptions(merge: true));
        },
        timeout: const Duration(seconds: 60),
        maxAttempts: 5,
      );
    } catch (e) {
      print('releaseActiveCreationSlot: $e');
    }
  }

  // Function to count users in active creation
  static Future<int> countUsersInActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef =
        firestore.collection('active_creation').doc('active_creation');

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('users')) {
          final users = data['users'] as List;
          return users.length;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching users from active_creation: $e');
      return -1;
    }
  }

  // Function to count API calls by user (keeps for backwards compatibility with call_count tracking)
  static Future<int> countAPIcallsByUser() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference userDocRef = firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid.toString())
        .collection('api_call_count')
        .doc('first_API_calls');

    try {
      final DocumentSnapshot doc = await userDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Keep showing call_count and last_call_date as is, but don't reset daily
        if (data.containsKey('call_count')) {
          return data['call_count'];
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
      return -1;
    }
  }

  // Function to get current daily lessons remaining
  static Future<int> getCurrentCredits() async {
    return await DailyLessonService.getRemainingLessons();
  }

  // Function to create a custom lesson
  static Future<void> createCustomLesson(
    BuildContext context,
    String topic,
    List<dynamic> selectedWords,
    String nativeLanguage,
    String targetLanguage,
    String languageLevel,
    Function setIsCreatingCustomLesson,
  ) async {
    // Validate inputs
    if (topic.trim().isEmpty) {
      safeShowSnackBar(
        context,
        const SnackBar(
          content: Text('Please enter a topic for your lesson'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (selectedWords.isEmpty) {
      safeShowSnackBar(
        context,
        const SnackBar(
          content: Text('Please add at least one word to learn'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setIsCreatingCustomLesson(true);

    // Check if context is still valid
    if (!context.mounted) {
      setIsCreatingCustomLesson(false);
      return;
    }

    String? documentId;
    String? userId;

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef =
          firestore.collection('chatGPT_responses').doc();
      documentId = docRef.id;
      userId = FirebaseAuth.instance.currentUser!.uid.toString();

      final reserved =
          await tryReserveActiveCreationSlot(userId, documentId);
      if (!reserved) {
        safeShowSnackBar(
          context,
          const SnackBar(
            content: Text(
                'Too many lessons are generating right now. Please try again in a moment.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      final response = await http
          .post(
            Uri.parse(
                'https://europe-west1-noble-descent-420612.cloudfunctions.net/translate_keywords'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              "Access-Control-Allow-Origin": "*",
            },
            body: jsonEncode(<String, dynamic>{
              "keywords": selectedWords,
              "target_language": targetLanguage,
              "native_language":
                  nativeLanguage, // Add the missing native_language parameter
            }),
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException('translate_keywords request');
            },
          );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        // Extract target language words from the new keyword format
        final List<dynamic> keywordObjects = data['keywords'] as List<dynamic>;
        // Store the bilingual keyword objects in local storage
        await storeKeywordTranslations(
            keywordObjects.cast<Map<String, dynamic>>(),
            targetLanguage,
            nativeLanguage);

        final List<dynamic> keywords = keywordObjects.map((keywordObj) {
          final Map<String, dynamic> keywordMap =
              keywordObj as Map<String, dynamic>;
          // Get the target language word (not the native language one)
          final targetLanguageWord = keywordMap[targetLanguage] as String;
          return targetLanguageWord
              .replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '')
              .toLowerCase();
        }).toList();
        print("keywords: $keywords");
        selectedWords = keywords;
      }

      // Create an empty script document ID
      DocumentReference scriptDocRef = firestore
          .collection('chatGPT_responses')
          .doc(documentId)
          .collection('script-$userId')
          .doc();

      // Make the API call
      http.post(
        Uri.parse('http://127.0.0.1:8081'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "requested_scenario": topic,
          "keywords": selectedWords,
          "native_language": nativeLanguage,
          "target_language": targetLanguage,
          "length": '${LessonConstants.defaultDialogueTurns}',
          "user_ID": userId,
          "language_level": languageLevel,
          "document_id": documentId,
          "tts_provider": targetLanguage == 'Azerbaijani'
              ? TTSProvider.openAI.value.toString()
              : TTSProvider.googleTTS.value.toString(),
        }),
      );

      // Check if context is still valid before navigation
      if (context.mounted) {
        // Play lesson using AudioPlayerManager
        final manager = Provider.of<AudioPlayerManager>(context, listen: false);
        manager.playLesson(LessonData(
          category: 'Custom Lesson',
          dialogue: const [],
          title: topic,
          documentID: documentId,
          userID: userId,
          scriptDocumentId: scriptDocRef.id,
          generating: true,
          targetLanguage: targetLanguage,
          nativeLanguage: nativeLanguage,
          languageLevel: languageLevel,
          wordsToRepeat: List<String>.from(selectedWords),
          numberOfTurns: LessonConstants.defaultDialogueTurns,
        ));
        await RecentLessonTopicsService.recordTopic(userId, targetLanguage, topic);
      }
    } catch (e) {
      print(e);
      if (userId != null && documentId != null) {
        try {
          await releaseActiveCreationSlot(userId, documentId).timeout(
            const Duration(seconds: 45),
            onTimeout: () {},
          );
        } catch (_) {}
      }
      safeShowSnackBar(
        context,
        const SnackBar(
          content: Text(
              'Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setIsCreatingCustomLesson(false);
    }
  }

  // Function to suggest a random lesson
  static Future<Map<String, dynamic>> suggestRandomLesson(
    String targetLanguage,
    String nativeLanguage, {
    List<String>? recentTopics,
  }) async {
    try {
      final body = <String, dynamic>{
        "target_language": targetLanguage,
        "native_language": nativeLanguage,
      };
      if (recentTopics != null && recentTopics.isNotEmpty) {
        body["recent_topics"] = recentTopics;
      }
      final response = await http.post(
        Uri.parse(
            'https://europe-west1-noble-descent-420612.cloudfunctions.net/suggest_custom_lesson'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get random lesson suggestion');
      }
    } catch (e) {
      throw Exception('Failed to get random suggestion: ${e.toString()}');
    }
  }

  // create a function to select words from the category according to certain criteria
  static Future<List<dynamic>> selectWordsFromCategory(
      String category, List<String> allWords, String targetLanguage) async {
    // check if there are due words in the category stored in the firestore
    final userId = FirebaseAuth.instance.currentUser!.uid.toString();
    final categoryDocs = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('${targetLanguage}_words')
        .doc(category)
        .collection(category)
        .get();

    var words = <String>[];
    final existingWordsCard = <String>[];
    final overdueWords = <String>[];
    final closestDueDateCard = <Map<String, dynamic>>[];

    // First, categorize existing words
    for (var doc in categoryDocs.docs) {
      // Handle both string and int formats for date fields
      DateTime dueDate;
      DateTime lastReview;

      final docData = doc.data();
      final dueField = docData['due'];
      if (dueField is String) {
        try {
          dueDate = DateTime.parse(dueField);
        } catch (e) {
          continue; // Skip this document if due date can't be parsed
        }
      } else {
        continue; // Skip this document if due date format is unexpected
      }

      final lastReviewField = docData['lastReview'];
      if (lastReviewField is String) {
        try {
          lastReview = DateTime.parse(lastReviewField);
        } catch (e) {
          continue; // Skip this document if lastReview date can't be parsed
        }
      } else if (lastReviewField is int) {
        lastReview = DateTime.fromMillisecondsSinceEpoch(lastReviewField);
      } else {
        continue; // Skip this document if lastReview format is unexpected
      }

      final daysOverdue = DateTime.now().difference(dueDate).inDays;
      final daysSinceLastReview = DateTime.now().difference(lastReview).inDays;

      final wordField = docData['word'];
      if (wordField == null || wordField is! String) {
        continue; // Skip this document if word field is missing or not a string
      }

      // Categorize words based on their status
      if (daysSinceLastReview > 0 && docData['scheduledDays'] >= 0) {
        if (daysOverdue >= 0) {
          overdueWords.add(wordField);
        } else {
          closestDueDateCard.add({
            'word': wordField,
            'due_date': docData['due'],
            'daysOverdue': daysOverdue,
          });
        }
      }
      existingWordsCard.add(wordField);
    }

    // PRIORITY 1: Add new words first (words not in existingWordsCard)
    final lowerCaseAllWords =
        allWords.map((word) => word.toLowerCase()).toList();
    final newWords = lowerCaseAllWords
        .where((word) => !existingWordsCard.contains(word))
        .toList();
    newWords.shuffle(); // randomize the newWords list

    if (newWords.isNotEmpty) {
      const cap = LessonConstants.maxWordsAllowed;
      final wordsToAdd =
          newWords.length >= cap ? newWords.sublist(0, cap) : newWords;
      words.addAll(wordsToAdd);
    }

    // PRIORITY 2: Add overdue words if we need more
    if (words.length < LessonConstants.maxWordsAllowed && overdueWords.isNotEmpty) {
      final wordsNeeded = LessonConstants.maxWordsAllowed - words.length;
      final wordsToAdd = overdueWords.length >= wordsNeeded
          ? overdueWords.sublist(0, wordsNeeded)
          : overdueWords;
      words.addAll(wordsToAdd);
    }

    // PRIORITY 3: Add closest to overdue words if we still need more
    if (words.length < LessonConstants.maxWordsAllowed && closestDueDateCard.isNotEmpty) {
      closestDueDateCard.sort((a, b) => a['due_date'].compareTo(b['due_date']));
      final wordsNeeded = LessonConstants.maxWordsAllowed - words.length;
      final wordsToAdd = closestDueDateCard.length >= wordsNeeded
          ? closestDueDateCard.sublist(0, wordsNeeded)
          : closestDueDateCard;
      words.addAll(wordsToAdd.map((item) => item['word'] as String));
    }

    // PRIORITY 4: just add random words if we still need more
    if (words.length < LessonConstants.maxWordsAllowed) {
      final wordsNeeded = LessonConstants.maxWordsAllowed - words.length;
      // randomize the allWords list
      final randomWords = allWords.toList();
      randomWords.shuffle();
      final wordsToAdd = randomWords.length >= wordsNeeded
          ? randomWords.sublist(0, wordsNeeded)
          : randomWords;
      words.addAll(wordsToAdd);
    }

    print('words selected: $words');
    return words;
  }

  // Function to clean up lesson data from local storage
  static Future<void> cleanupLessonData(String targetLanguage) async {
    try {
      await clearKeywordTranslations(targetLanguage);
    } catch (e) {
      print('Error cleaning up lesson data: $e');
    }
  }
}
