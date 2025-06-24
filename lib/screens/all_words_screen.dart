import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/utils/script_generator.dart' show getDocsAndRefsMaps;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart' show WordCard;

import 'package:parakeet/utils/mark_as_mastered_modal.dart' show showMarkAsMasteredModal;
import 'package:parakeet/utils/language_categories.dart';

class AllWordsScreen extends StatefulWidget {
  final String? nativeLanguage;

  const AllWordsScreen({
    Key? key,
    this.nativeLanguage,
  }) : super(key: key);

  @override
  State<AllWordsScreen> createState() => _AllWordsScreenState();
}

class _AllWordsScreenState extends State<AllWordsScreen> {
  late bool _isLoadingAll;
  late String _userId;
  late String _targetLanguage;
  late String _nativeLanguage;

  // Categories for both languages
  late List<Map<String, dynamic>> _targetLanguageCategories;
  late List<Map<String, dynamic>> _nativeLanguageCategories;

  final List<WordCard> _allWordsFull = [];

  int _allPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _isLoadingAll = true;
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('AllWordsScreen: No Firebase user found.');
        setState(() {
          _isLoadingAll = false;
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
    } catch (e, stack) {
      debugPrint('AllWordsScreen: Error in _initializeData: \n$e\n$stack');
      setState(() {
        _isLoadingAll = false;
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

      // Convert to WordCard objects first for easier sorting
      final wordCards = docs.map(WordCard.fromFirestore).toList();

      // Sort words by learning status and then alphabetically within each group
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
      debugPrint('AllWordsScreen: Error in _loadAllWords: \n$e\n$stack');
      setState(() {
        _isLoadingAll = false;
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

                // Word and translation on the same row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Text(
                        word,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    Expanded(
                      child: Text(
                        nativeWord,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
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

  // Calculate mastery progress based on scheduled days and reps
  double _calculateMasteryProgress(WordCard card) {
    final scheduledDays = card.card.scheduledDays.toDouble();
    final reps = card.card.reps;

    // If mastered (scheduledDays == -1 or >= 100), return 1.0 (100%)
    if (scheduledDays == -1 || scheduledDays >= 100) {
      return 1.0;
    }

    // If no reps, return 0.0 (0%)
    if (reps == 0) {
      return 0.0;
    }

    // For learning words, calculate progress based on scheduled days
    // Assume 100 days is full mastery, scale accordingly
    if (scheduledDays > 0) {
      return (scheduledDays / 100).clamp(0.0, 1.0);
    }

    // For words due for review (scheduledDays == 0), use reps as indicator
    // More reps = higher progress (cap at reasonable number)
    return (reps / 10).clamp(0.1, 0.8); // Between 10% and 80% for due words
  }

  Color _getMasteryProgressColor(double progress, ColorScheme colorScheme) {
    if (progress >= 0.9) {
      return Colors.green;
    } else if (progress >= 0.6) {
      return Colors.blue;
    } else if (progress >= 0.3) {
      return Colors.orange;
    } else {
      return colorScheme.onSurfaceVariant.withOpacity(0.6);
    }
  }

  Widget _buildWordItem(WordCard card, ColorScheme colorScheme) {
    final scheduledDays = card.card.scheduledDays.toDouble();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = card.card.due;
    final isOverdue = dueDate.isBefore(now) || dueDate.isAtSameMomentAs(now);
    final translation = findWordTranslation(card.word);
    final hasTranslation = translation != null;

    // Check if lastReview was today
    final lastReviewDate = DateTime(
      card.card.lastReview.year,
      card.card.lastReview.month,
      card.card.lastReview.day,
    );
    final reviewedToday = lastReviewDate.isAtSameMomentAs(today);

    String reviewText;
    if (isOverdue && !reviewedToday) {
      reviewText = 'Ready for review';
    } else if (scheduledDays == -1) {
      reviewText = 'Mastered';
    } else {
      final daysUntilDue = dueDate.difference(now).inDays;
      if (daysUntilDue == 0) {
        reviewText = 'Today';
      } else if (daysUntilDue == 1) {
        reviewText = '1 day left';
      } else {
        reviewText = '$daysUntilDue days left';
      }
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
                  color: (isOverdue && !reviewedToday)
                      ? Colors.white
                      : scheduledDays == -1
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(width: 16),

            // Mastery Progress
            SizedBox(
              width: 70,
              child: Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _calculateMasteryProgress(card),
                        strokeWidth: 3,
                        backgroundColor: colorScheme.onSurfaceVariant.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getMasteryProgressColor(_calculateMasteryProgress(card), colorScheme),
                        ),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Text(
                            '${(_calculateMasteryProgress(card) * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
          'Word Bank',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildAllWordsView(isSmallScreen, colorScheme),
    );
  }

  Widget _buildAllWordsView(bool isSmallScreen, ColorScheme colorScheme) {
    if (_isLoadingAll) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allWordsFull.isEmpty) {
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
                const TextSpan(text: "Nothing to see here yet! Head to the ", style: TextStyle(fontStyle: FontStyle.italic)),
                TextSpan(
                  text: 'create lesson tab',
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
                ),
                const TextSpan(text: ' to start your learning journey!', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      );
    }
    final displayed = _allWordsFull.take((_allPage + 1) * _pageSize).toList();

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
                'These are words you have started learning.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
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
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: Text(
                  'Mastery',
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
                if (displayed.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                    child: () {
                      // Check if any displayed words have translations
                      final hasAnyTranslations = displayed.any((card) => findWordTranslation(card.word) != null);

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
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: displayed.length + (displayed.length < _allWordsFull.length ? 1 : 0),
                    itemBuilder: (context, index) {
                      // If this is the last item and there are more words to show, display the "Show More" button
                      if (index == displayed.length && displayed.length < _allWordsFull.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                          child: Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _allPage++;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Show More',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more,
                                    size: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      // Otherwise, display the word item
                      final card = displayed[index];
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
