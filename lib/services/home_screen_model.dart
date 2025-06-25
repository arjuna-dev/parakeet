import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/services/user_service.dart';

class HomeScreenModel extends ChangeNotifier {
  bool _isDisposed = false;
  List<DocumentSnapshot> allLessons = [];
  List<DocumentSnapshot> filteredLessons = [];
  final user = FirebaseAuth.instance.currentUser;

  // Category filtering
  String? selectedCategory;
  List<String> availableCategories = [];

  // Search functionality
  String searchQuery = '';

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  Future<void> loadAllLessons() async {
    final userId = user!.uid;

    // Get user's current target language preference
    final userSettings = await UserService.getUserLanguageSettings();
    final userTargetLanguage = userSettings['targetLanguage']!;

    final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

    // Filter lessons by user's current target language
    final lessonsForCurrentLanguage = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final lessonTargetLanguage = data['target_language']?.toString();
      return lessonTargetLanguage == userTargetLanguage;
    }).toList();

    // Sort by timestamp (newest first)
    allLessons = lessonsForCurrentLanguage;
    allLessons.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

    // Extract unique categories
    _extractCategories();

    // Apply current filter
    _applyFilter();

    safeNotifyListeners();
  }

  void _extractCategories() {
    Set<String> categories = {};
    for (var lesson in allLessons) {
      final data = lesson.data() as Map<String, dynamic>?;
      if (data?.containsKey('category') == true && lesson.get('category') != null && lesson.get('category').toString().trim().isNotEmpty) {
        categories.add(lesson.get('category'));
      } else {
        categories.add('Custom Lesson');
      }
    }
    availableCategories = categories.toList()..sort();
  }

  void setSelectedCategory(String? category) {
    selectedCategory = category;
    _applyFilter();
    safeNotifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    _applyFilter();
    safeNotifyListeners();
  }

  void clearSearch() {
    searchQuery = '';
    _applyFilter();
    safeNotifyListeners();
  }

  void _applyFilter() {
    List<DocumentSnapshot> lessonsToFilter = List.from(allLessons);

    // Apply category filter first
    if (selectedCategory != null && selectedCategory != 'All Categories') {
      lessonsToFilter = lessonsToFilter.where((lesson) {
        final data = lesson.data() as Map<String, dynamic>?;
        String lessonCategory;
        if (data?.containsKey('category') == true && lesson.get('category') != null && lesson.get('category').toString().trim().isNotEmpty) {
          lessonCategory = lesson.get('category');
        } else {
          lessonCategory = 'Custom Lesson';
        }
        return lessonCategory == selectedCategory;
      }).toList();
    }

    // Apply search filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      lessonsToFilter = lessonsToFilter.where((lesson) {
        final data = lesson.data() as Map<String, dynamic>?;
        if (data == null) return false;

        // Search in title
        final title = data['title']?.toString().toLowerCase() ?? '';
        if (title.contains(query)) return true;

        // Search in category
        final category = data['category']?.toString().toLowerCase() ?? 'custom lesson';
        if (category.contains(query)) return true;

        // Search in target language
        final targetLanguage = data['target_language']?.toString().toLowerCase() ?? '';
        if (targetLanguage.contains(query)) return true;

        // Search in native language
        final nativeLanguage = data['native_language']?.toString().toLowerCase() ?? '';
        if (nativeLanguage.contains(query)) return true;

        // Search in words to repeat
        final wordsToRepeat = data['words_to_repeat'] as List<dynamic>?;
        if (wordsToRepeat != null) {
          for (var word in wordsToRepeat) {
            if (word.toString().toLowerCase().contains(query)) return true;
          }
        }

        // Search in dialogue content
        final dialogue = data['dialogue'] as List<dynamic>?;
        if (dialogue != null) {
          for (var turn in dialogue) {
            if (turn is Map<String, dynamic>) {
              final speakerText = turn['speaker']?.toString().toLowerCase() ?? '';
              final text = turn['text']?.toString().toLowerCase() ?? '';
              if (speakerText.contains(query) || text.contains(query)) return true;
            }
          }
        }

        return false;
      }).toList();
    }

    filteredLessons = lessonsToFilter;
  }
}
