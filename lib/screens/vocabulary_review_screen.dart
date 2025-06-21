import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/utils/script_generator.dart' show getDocsAndRefsMaps;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart' show WordCard;
import 'package:parakeet/widgets/home_screen/tab_content_view.dart';

import 'package:parakeet/widgets/audio_player_screen/review_words_dialog.dart';
import 'package:parakeet/screens/category_detail_screen.dart' show showCenteredToast;
import 'package:parakeet/utils/mark_as_mastered_modal.dart' show showMarkAsMasteredModal;
import 'package:parakeet/utils/language_categories.dart';

class VocabularyReviewScreen extends StatefulWidget {
  final String? nativeLanguage;

  const VocabularyReviewScreen({
    Key? key,
    this.nativeLanguage,
  }) : super(key: key);

  @override
  State<VocabularyReviewScreen> createState() => _VocabularyReviewScreenState();
}

class _VocabularyReviewScreenState extends State<VocabularyReviewScreen> {
  late Map<String, DocumentReference> _allRefsMap;
  late bool _isLoadingAll;
  late bool _isLoadingDue;
  late String _userId;
  late String _targetLanguage;
  late String _nativeLanguage;

  // Categories for both languages
  late List<Map<String, dynamic>> _targetLanguageCategories;
  late List<Map<String, dynamic>> _nativeLanguageCategories;

  final List<WordCard> _allWordsFull = [];
  final List<WordCard> _dueWordsFull = [];
  final Map<String, DocumentReference> _dueWordsRefs = {};
  int _totalDueWordsCount = 0; // Track total words available for review

  @override
  void initState() {
    super.initState();
    _isLoadingAll = true;
    _isLoadingDue = true;
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('WordManagementScreen: No Firebase user found.');
        setState(() {
          _isLoadingAll = false;
          _isLoadingDue = false;
        });
        return;
      }
      _userId = user.uid;
      final userData = await ProfileService.fetchUserData();
      _targetLanguage = userData['target_language'] as String? ?? '';
      _nativeLanguage = widget.nativeLanguage ?? userData['native_language'] as String? ?? 'English (US)';

      // Load categories for both languages
      _targetLanguageCategories = getCategoriesForLanguage(_targetLanguage);
      _nativeLanguageCategories = getCategoriesForLanguage(_nativeLanguage);

      await _loadAllWords();
      await _loadDueWords();
    } catch (e, stack) {
      debugPrint('WordManagementScreen: Error in _initializeData: \n$e\n$stack');
      setState(() {
        _isLoadingAll = false;
        _isLoadingDue = false;
      });
    }
  }

  Future<void> _loadAllWords() async {
    setState(() => _isLoadingAll = true);
    try {
      final categoriesRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('${_targetLanguage}_words');
      final categories = await categoriesRef.get();
      final refs = <DocumentReference>[];
      for (var cat in categories.docs) {
        // Skip Custom Lesson words
        if (cat.id.toLowerCase() == 'custom lesson') {
          continue;
        }
        final wordsCol = categoriesRef.doc(cat.id).collection(cat.id);
        final snap = await wordsCol.get();
        for (var doc in snap.docs) {
          refs.add(doc.reference);
        }
      }
      final maps = await getDocsAndRefsMaps(refs);
      final docs = maps['docs'] as List<Map<String, dynamic>>;
      _allRefsMap = maps['refsMap'] as Map<String, DocumentReference>;

      // Convert to WordCard objects first for easier sorting
      final wordCards = docs.map(WordCard.fromFirestore).toList(); // Sort words by learning status and then alphabetically within each group
      wordCards.sort((a, b) {
        // Get status flags for word A
        final scheduledDaysA = a.card.scheduledDays.toDouble();
        final learningA = a.card.reps > 0;
        final isMasteredA = scheduledDaysA >= 100 || scheduledDaysA == -1;

        // Get status flags for word B
        final scheduledDaysB = b.card.scheduledDays.toDouble();
        final learningB = b.card.reps > 0;
        final isMasteredB = scheduledDaysB >= 100 || scheduledDaysB == -1;

        // Assign category values for sorting priority:
        // 0: Learning (has reps but not mastered)
        // 1: Not Started (no reps)
        // 2: Mastered
        int categoryA;
        int categoryB;

        if (learningA && !isMasteredA) {
          categoryA = 0; // Learning
        } else if (!learningA) {
          categoryA = 1; // Not started
        } else {
          categoryA = 2; // Mastered
        }

        if (learningB && !isMasteredB) {
          categoryB = 0; // Learning
        } else if (!learningB) {
          categoryB = 1; // Not started
        } else {
          categoryB = 2; // Mastered
        }

        // Sort by category first
        if (categoryA != categoryB) {
          return categoryA.compareTo(categoryB);
        }

        // Same status, sort alphabetically
        return a.word.compareTo(b.word);
      });

      setState(() {
        _allWordsFull
          ..clear()
          ..addAll(wordCards);
        _isLoadingAll = false;
      });
    } catch (e, stack) {
      debugPrint('WordManagementScreen: Error in _loadAllWords: \n$e\n$stack');
      setState(() {
        _isLoadingAll = false;
      });
    }
  }

  Future<void> _loadDueWords() async {
    setState(() => _isLoadingDue = true);
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Filter _allWordsFull for words where due date is today or in the past AND not reviewed today
      final dueWords = _allWordsFull.where((wordCard) {
        // Check if the word is due (due date <= now)
        final dueDate = wordCard.card.due;
        final isOverdue = dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now);

        if (!isOverdue) return false;

        // Check if lastReview was today
        final lastReviewDate = DateTime(
          wordCard.card.lastReview.year,
          wordCard.card.lastReview.month,
          wordCard.card.lastReview.day,
        );

        // Exclude if reviewed today
        return !lastReviewDate.isAtSameMomentAs(today);
      }).toList();

      // Optionally, sort as before (by learning status and alphabetically)
      dueWords.sort((a, b) {
        final scheduledDaysA = a.card.scheduledDays.toDouble();
        final learningA = a.card.reps > 0;
        final isMasteredA = scheduledDaysA >= 100 || scheduledDaysA == -1;

        final scheduledDaysB = b.card.scheduledDays.toDouble();
        final learningB = b.card.reps > 0;
        final isMasteredB = scheduledDaysB >= 100 || scheduledDaysB == -1;

        int categoryA = 0;
        int categoryB = 0;

        if (learningA && !isMasteredA)
          categoryA = 0;
        else if (!learningA)
          categoryA = 1;
        else if (isMasteredA) categoryA = 2;

        if (learningB && !isMasteredB)
          categoryB = 0;
        else if (!learningB)
          categoryB = 1;
        else if (isMasteredB) categoryB = 2;

        if (categoryA != categoryB) {
          return categoryA.compareTo(categoryB);
        }
        return a.word.compareTo(b.word);
      });

      final refsMap = _allRefsMap;
      // Build a map of only due words and their references
      final dueWordsRefs = <String, DocumentReference>{};
      for (final wordCard in dueWords) {
        final ref = refsMap[wordCard.word];
        if (ref != null) {
          dueWordsRefs[wordCard.word] = ref;
        }
      }
      // Store total count before limiting
      _totalDueWordsCount = dueWords.length;

      // Limit to maximum 20 words for review
      final limitedDueWords = dueWords.take(20).toList();
      final limitedDueWordsRefs = <String, DocumentReference>{};
      for (final wordCard in limitedDueWords) {
        final ref = refsMap[wordCard.word];
        if (ref != null) {
          limitedDueWordsRefs[wordCard.word] = ref;
        }
      }

      setState(() {
        _dueWordsFull
          ..clear()
          ..addAll(limitedDueWords);
        _dueWordsRefs
          ..clear()
          ..addAll(limitedDueWordsRefs);
        _isLoadingDue = false;
      });
    } catch (e, stack) {
      debugPrint('WordManagementScreen: Error in _loadDueWords: \n$e\n$stack');
      setState(() {
        _isLoadingDue = false;
      });
    }
  }

  // Method to find word translation by looking up the category and index
  String? findWordTranslation(String word) {
    // Find the category and index of the word in target language
    for (final targetCategory in _targetLanguageCategories) {
      final List<dynamic> words = targetCategory['words'];
      final int wordIndex = words.indexWhere((w) => w.toLowerCase() == word.toLowerCase());

      if (wordIndex != -1) {
        // Found the word, now find matching category in native language
        final String categoryName = targetCategory['name'];

        final matchingNativeCategory = _nativeLanguageCategories.firstWhere(
          (natCat) {
            return natCat['name'] == categoryName;
          },
          orElse: () => <String, Object>{'words': <Object>[]},
        );
        // Get the translation at the same index if available
        final List<dynamic> nativeWords = matchingNativeCategory['words'] as List<dynamic>;
        if (nativeWords.isNotEmpty && wordIndex < nativeWords.length) {
          final translation = "${nativeWords[wordIndex]}";
          // Only return translation if it's different from the original word
          if (translation.toLowerCase() != word.toLowerCase()) {
            return translation;
          }
        }
      }
    }
    // If word not found in any category or matching translation not found
    return null;
  }

  // Helper method to show translated word in toast
  void _showTranslatedWordToast(BuildContext context, String word) {
    final translation = findWordTranslation(word);
    if (translation != null) {
      showCenteredToast(context, translation);
    } else {
      showCenteredToast(context, word); // Show original word if no translation
    }
  }

  // Helper method to show translation in a modal sheet
  void _showTranslationSheet(BuildContext context, String word, String nativeWord) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(height: 20),

                // Target language word
                Text(
                  word,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(height: 8),

                // Arrow or divider
                Icon(
                  Icons.arrow_downward_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),

                const SizedBox(height: 8),

                // Native language translation
                Text(
                  nativeWord,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _findCategoryName(String word) {
    for (final targetCategory in _targetLanguageCategories) {
      final List<dynamic> words = targetCategory['words'];
      if (words.any((w) => w.toLowerCase() == word.toLowerCase())) {
        return targetCategory['name'] as String;
      }
    }
    return null;
  }

  Widget _buildWordItem(WordCard card, ColorScheme colorScheme) {
    final scheduledDays = card.card.scheduledDays.toDouble();
    final now = DateTime.now();
    final dueDate = card.card.due;
    final isOverdue = dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now);
    final translation = findWordTranslation(card.word);
    final hasTranslation = translation != null;

    String reviewText;
    if (isOverdue) {
      reviewText = 'Ready for review';
    } else if (scheduledDays == -1) {
      reviewText = 'Mastered';
    } else {
      final daysUntilDue = dueDate.difference(now).inDays;
      reviewText = '$daysUntilDue days';
    }

    return InkWell(
      onTap: hasTranslation ? () => _showTranslationSheet(context, card.word, translation) : null,
      onLongPress: () {
        final categoryName = _findCategoryName(card.word);
        if (categoryName != null) {
          showMarkAsMasteredModal(
            context: context,
            word: card.word,
            categoryName: categoryName,
            targetLanguage: _targetLanguage,
            learningWords: List<Map<String, dynamic>>.from(_allWordsFull.map((c) => <String, dynamic>{
                  'word': c.word.toLowerCase(),
                  'scheduledDays': c.card.scheduledDays.toDouble(),
                  'reps': c.card.reps,
                })),
            updateLearningWords: (_) {},
            loadWordStats: () async {
              await _loadAllWords();
              await _loadDueWords();
            },
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.onSurfaceVariant.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Word
            Expanded(
              child: Text(
                card.word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Review Time
            SizedBox(
              width: 100,
              child: Text(
                reviewText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isOverdue
                      ? colorScheme.primary
                      : scheduledDays == -1
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Vocabulary Review',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: TabContentView(
        isSmallScreen: isSmallScreen,
        child: _buildDueWordsTab(isSmallScreen, colorScheme),
      ),

      // Floating Action Button for Review
      floatingActionButton: !_isLoadingDue && _dueWordsFull.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 20, right: 4),
              child: FloatingActionButton.extended(
                onPressed: () => _showReviewOptions(context),
                backgroundColor: colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 8,
                icon: const Icon(Icons.quiz_rounded, size: 22),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Review Words',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      _totalDueWordsCount > 20 ? '${_dueWordsFull.length} of $_totalDueWordsCount ready' : '${_dueWordsFull.length} ready',
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _showReviewOptions(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Modal header
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.quiz_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Options',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              _totalDueWordsCount > 20 ? '${_dueWordsFull.length} of $_totalDueWordsCount words ready for review' : '${_dueWordsFull.length} words ready for review',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Card Review Option (Primary)
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      builder: (context) => ReviewWordsDialog(
                        words: _dueWordsRefs,
                        userID: _userId,
                        onReviewCompleted: () async {
                          // Refresh the word lists after review is completed
                          await _loadAllWords();
                          await _loadDueWords();
                        },
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.1),
                          colorScheme.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.style_rounded,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Card Review',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Recommended',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Visual flashcard review where you test and rate your memory',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // New Lesson Option
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacementNamed(context, '/create_lesson');
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              size: 28,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Lesson',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Create a lesson with context, new words, and review overdue words',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Audio Review Option (Coming Soon)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.headset_rounded,
                            size: 28,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Audio Review',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Coming Soon',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Audio-based review with pronunciation practice',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDueWordsTab(bool isSmallScreen, ColorScheme colorScheme) {
    if (_isLoadingDue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_dueWordsFull.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              children: [
                const TextSpan(text: 'You are up to speed with your learning! To continue on your journey ', style: TextStyle(fontStyle: FontStyle.italic)),
                TextSpan(
                  text: 'create a new lesson',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacementNamed(context, '/create_lesson');
                    },
                )
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are words due for review based on our advanced FSRS algorithm.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
              if (_totalDueWordsCount > 20) ...[
                SizedBox(height: isSmallScreen ? 8 : 12),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing 20 words at a time to optimize your learning. Complete this session to access more words.',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: isSmallScreen ? 12 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Column Headers
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Word',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: Text(
                  'Next Review',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: Container(
            margin: const EdgeInsets.all(0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                if (_dueWordsFull.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: () {
                      // Check if any displayed words have translations
                      final hasAnyTranslations = _dueWordsFull.any((card) => findWordTranslation(card.word) != null);

                      String instructionText;
                      if (hasAnyTranslations) {
                        instructionText = 'Tap any word to see its translation • Long press for options';
                      } else {
                        instructionText = 'Long press any word for options';
                      }

                      return Text(
                        instructionText,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }(),
                  ),
                ],
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 100),
                    itemCount: _dueWordsFull.length,
                    itemBuilder: (context, index) {
                      final card = _dueWordsFull[index];
                      return _buildWordItem(card, colorScheme);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
