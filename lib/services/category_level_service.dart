import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CategoryLevel {
  final int currentLevel; // 1, 2, or 3
  final int completedLessons;
  final int requiredLessons;
  final bool isLevelCompleted;
  final bool canAccessNextLevel;

  CategoryLevel({
    required this.currentLevel,
    required this.completedLessons,
    required this.requiredLessons,
    required this.isLevelCompleted,
    required this.canAccessNextLevel,
  });

  double get progressPercentage => requiredLessons > 0 ? (completedLessons / requiredLessons) * 100 : 0;

  String get levelName {
    switch (currentLevel) {
      case 1:
        return 'Beginner';
      case 2:
        return 'Intermediate';
      case 3:
        return 'Advanced';
      default:
        return 'Unknown';
    }
  }
}

class CategoryLevelService {
  // Level requirements
  static const Map<int, int> levelRequirements = {
    1: 3, // Beginner: 3 lessons
    2: 5, // Intermediate: 5 lessons
    3: 8, // Advanced: 8 lessons
  };

  static const int maxLevel = 3;

  /// Get the current level status for a specific category
  static Future<CategoryLevel> getCategoryLevel(
    String categoryName,
    String targetLanguage,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Get level progress from Firestore
      final levelDoc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('category_levels').doc('${targetLanguage}_$categoryName').get();

      int currentLevel = 1;
      Map<int, int> completedLessonsPerLevel = {1: 0, 2: 0, 3: 0};

      if (levelDoc.exists) {
        final data = levelDoc.data()!;
        currentLevel = data['currentLevel'] ?? 1;
        completedLessonsPerLevel = {
          1: data['level1Completed'] ?? 0,
          2: data['level2Completed'] ?? 0,
          3: data['level3Completed'] ?? 0,
        };
      }

      final requiredLessons = levelRequirements[currentLevel] ?? 3;
      final completedLessons = completedLessonsPerLevel[currentLevel] ?? 0;
      final isLevelCompleted = completedLessons >= requiredLessons;
      final canAccessNextLevel = currentLevel < maxLevel && isLevelCompleted;

      return CategoryLevel(
        currentLevel: currentLevel,
        completedLessons: completedLessons,
        requiredLessons: requiredLessons,
        isLevelCompleted: isLevelCompleted,
        canAccessNextLevel: canAccessNextLevel,
      );
    } catch (e) {
      print('Error getting category level: $e');
      return CategoryLevel(
        currentLevel: 1,
        completedLessons: 0,
        requiredLessons: levelRequirements[1]!,
        isLevelCompleted: false,
        canAccessNextLevel: false,
      );
    }
  }

  /// Record a completed lesson for a category
  static Future<void> recordCompletedLesson(
    String categoryName,
    String targetLanguage,
    int lessonLevel,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final docRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('category_levels').doc('${targetLanguage}_$categoryName');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        Map<String, dynamic> data = {
          'categoryName': categoryName,
          'targetLanguage': targetLanguage,
          'currentLevel': 1,
          'level1Completed': 0,
          'level2Completed': 0,
          'level3Completed': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (doc.exists) {
          data = Map<String, dynamic>.from(doc.data()!);
        }

        // Increment completed lessons for the specific level
        final levelKey = 'level${lessonLevel}Completed';
        data[levelKey] = (data[levelKey] ?? 0) + 1;
        data['lastUpdated'] = FieldValue.serverTimestamp();

        // Check if current level is completed and advance to next level
        final currentLevel = data['currentLevel'] ?? 1;
        final currentLevelCompleted = data['level${currentLevel}Completed'] ?? 0;
        final requiredForCurrentLevel = levelRequirements[currentLevel] ?? 3;

        if (currentLevel == lessonLevel && currentLevelCompleted >= requiredForCurrentLevel && currentLevel < maxLevel) {
          data['currentLevel'] = currentLevel + 1;
        }

        transaction.set(docRef, data, SetOptions(merge: true));
      });
    } catch (e) {
      print('Error recording completed lesson: $e');
    }
  }

  /// Get all category levels for a target language
  static Future<Map<String, CategoryLevel>> getAllCategoryLevels(
    String targetLanguage,
    List<String> categoryNames,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final results = <String, CategoryLevel>{};

      // Get all level documents for this language
      final querySnapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('category_levels').where('targetLanguage', isEqualTo: targetLanguage).get();

      final existingLevels = <String, Map<String, dynamic>>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final categoryName = data['categoryName'] as String?;
        if (categoryName != null) {
          existingLevels[categoryName] = data;
        }
      }

      // Process each category
      for (final categoryName in categoryNames) {
        if (existingLevels.containsKey(categoryName)) {
          final data = existingLevels[categoryName]!;
          final currentLevel = data['currentLevel'] ?? 1;
          final completedLessons = data['level${currentLevel}Completed'] ?? 0;
          final requiredLessons = levelRequirements[currentLevel] ?? 3;
          final isLevelCompleted = completedLessons >= requiredLessons;
          final canAccessNextLevel = currentLevel < maxLevel && isLevelCompleted;

          results[categoryName] = CategoryLevel(
            currentLevel: currentLevel,
            completedLessons: completedLessons,
            requiredLessons: requiredLessons,
            isLevelCompleted: isLevelCompleted,
            canAccessNextLevel: canAccessNextLevel,
          );
        } else {
          // Category not yet started
          results[categoryName] = CategoryLevel(
            currentLevel: 1,
            completedLessons: 0,
            requiredLessons: levelRequirements[1]!,
            isLevelCompleted: false,
            canAccessNextLevel: false,
          );
        }
      }

      return results;
    } catch (e) {
      print('Error getting all category levels: $e');
      return {};
    }
  }

  /// Reset a category's progress (for testing or admin purposes)
  static Future<void> resetCategoryProgress(
    String categoryName,
    String targetLanguage,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('category_levels').doc('${targetLanguage}_$categoryName').delete();
    } catch (e) {
      print('Error resetting category progress: $e');
    }
  }

  /// Get level color for UI
  static Color getLevelColor(int level) {
    switch (level) {
      case 1:
        return const Color(0xFF4CAF50); // Green for Beginner
      case 2:
        return const Color(0xFFFF9800); // Orange for Intermediate
      case 3:
        return const Color(0xFFF44336); // Red for Advanced
      default:
        return const Color(0xFF9E9E9E); // Gray for unknown
    }
  }

  /// Get level icon for UI
  static IconData getLevelIcon(int level) {
    switch (level) {
      case 1:
        return Icons.child_care_rounded; // Child icon for Beginner
      case 2:
        return Icons.school_rounded; // School icon for Intermediate
      case 3:
        return Icons.psychology_rounded; // Brain icon for Advanced
      default:
        return Icons.help_outline_rounded;
    }
  }

  /// Get cumulative required lessons up to a specific level
  /// Level 1: 3 lessons, Level 2: 3+5=8 lessons, Level 3: 3+5+8=16 lessons
  static int getCumulativeRequiredLessons(int level) {
    // Handle case where level is 0 or negative
    if (level <= 0) return 0;

    int cumulative = 0;
    for (int i = 1; i <= level; i++) {
      cumulative += levelRequirements[i] ?? 0;
    }
    return cumulative;
  }

  /// Get the current level status for a category based on actual completed lessons
  /// This method counts actual completed lessons from the database to ensure accuracy
  static Future<CategoryLevel> getCategoryLevelFromActualLessons(
    String categoryName,
    String targetLanguage,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        return CategoryLevel(
          currentLevel: 1,
          completedLessons: 0,
          requiredLessons: levelRequirements[1]!,
          isLevelCompleted: false,
          canAccessNextLevel: false,
        );
      }

      // Get all lessons for this category
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

      final categoryLessons = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        // Filter by category
        String lessonCategory;
        if (data?.containsKey('category') == true && doc.get('category') != null && doc.get('category').toString().trim().isNotEmpty) {
          lessonCategory = doc.get('category');
        } else {
          lessonCategory = 'Custom Lesson';
        }

        // Filter by target language
        final lessonTargetLanguage = data?['target_language']?.toString();

        return lessonCategory == categoryName && lessonTargetLanguage == targetLanguage;
      }).toList();

      // Count completed lessons by level
      final Map<int, int> completedLessonsByLevel = {1: 0, 2: 0, 3: 0};

      for (final doc in categoryLessons) {
        final parentDocId = doc.reference.parent.parent!.id;
        try {
          final lessonDoc = await FirebaseFirestore.instance.collection('chatGPT_responses').doc(parentDocId).get();
          if (lessonDoc.exists) {
            final lessonData = lessonDoc.data();
            final isCompleted = lessonData?['completed'] == true;
            final lessonLevel = lessonData?['categoryLevel'] ?? 1;

            if (isCompleted && lessonLevel >= 1 && lessonLevel <= 3) {
              completedLessonsByLevel[lessonLevel] = (completedLessonsByLevel[lessonLevel] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('Error checking completion for lesson $parentDocId: $e');
        }
      }

      // Determine current level based on completed lessons
      int currentLevel = 1;
      for (int level = 1; level <= 3; level++) {
        final requiredForThisLevel = levelRequirements[level] ?? 3;
        final completedForThisLevel = completedLessonsByLevel[level] ?? 0;

        if (completedForThisLevel >= requiredForThisLevel) {
          // Level is completed, check if we can advance
          if (level < 3) {
            currentLevel = level + 1;
          } else {
            currentLevel = 3; // Max level
          }
        } else {
          // This level is not completed, so this is our current level
          currentLevel = level;
          break;
        }
      }

      // Get progress for the current level
      final requiredLessons = levelRequirements[currentLevel] ?? 3;
      final completedLessons = completedLessonsByLevel[currentLevel] ?? 0;
      final isLevelCompleted = completedLessons >= requiredLessons;
      final canAccessNextLevel = currentLevel < maxLevel && isLevelCompleted;

      return CategoryLevel(
        currentLevel: currentLevel,
        completedLessons: completedLessons,
        requiredLessons: requiredLessons,
        isLevelCompleted: isLevelCompleted,
        canAccessNextLevel: canAccessNextLevel,
      );
    } catch (e) {
      print('Error getting category level from actual lessons: $e');
      return CategoryLevel(
        currentLevel: 1,
        completedLessons: 0,
        requiredLessons: levelRequirements[1]!,
        isLevelCompleted: false,
        canAccessNextLevel: false,
      );
    }
  }
}
