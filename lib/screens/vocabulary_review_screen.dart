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

class _VocabularyReviewScreenState extends State<VocabularyReviewScreen> with TickerProviderStateMixin {
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

  // Track flipped state for each word
  final Map<String, bool> _flippedCards = {};

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
      showCenteredToast(context, "No translation available"); // Show message if no translation
    }
  }

  // Helper method to show translation in a modal sheet
  void _showTranslationSheet(BuildContext context, String word, String? nativeWord) {
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
                  (nativeWord?.isNotEmpty == true) ? nativeWord! : "No translation available",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: (nativeWord?.isNotEmpty == true) ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
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

  Widget _buildWordCard(WordCard card, ColorScheme colorScheme) {
    final translation = findWordTranslation(card.word);
    final isFlipped = _flippedCards[card.word] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _flippedCards[card.word] = !isFlipped;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotateAnim = Tween(begin: 1.0, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, child) {
              final isShowingFront = ValueKey(isFlipped) != child!.key;
              var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
              tilt *= isShowingFront ? -1.0 : 1.0;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(rotateAnim.value * 3.14159),
                child: child,
              );
            },
          );
        },
        child: isFlipped ? _buildCardBack(card.word, translation, colorScheme) : _buildCardFront(card.word, colorScheme),
      ),
    );
  }

  Widget _buildCardFront(String word, ColorScheme colorScheme) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: Text(
          word,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildCardBack(String word, String? translation, ColorScheme colorScheme) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: translation ?? "N/A",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: translation != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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

      // Bottom Navigation Bar with Review Button
      bottomNavigationBar: !_isLoadingDue && _dueWordsFull.isNotEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () {
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.quiz_rounded, size: 22),
                label: const Text(
                  'Review Words',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          : null,
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
                'These are words due for review.',
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

        // Instructions
        if (_dueWordsFull.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'Tap any card to flip and see the translation',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // Words Grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 20,
                childAspectRatio: 1.8,
              ),
              itemCount: _dueWordsFull.length,
              itemBuilder: (context, index) {
                final card = _dueWordsFull[index];
                return _buildWordCard(card, colorScheme);
              },
            ),
          ),
        ),
      ],
    );
  }
}
