import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:parakeet/utils/mark_as_mastered_modal.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/services/word_stats_service.dart';
import 'package:parakeet/services/category_level_service.dart';
import 'package:parakeet/screens/level_detail_screen.dart';

// Global variable to track active toast
OverlayEntry? _activeToastEntry;

class CategoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final Map<String, dynamic> nativeCategory;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;

  const CategoryDetailScreen({
    Key? key,
    required this.category,
    required this.nativeCategory,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final List<Map<String, dynamic>> _learningWords = [];
  bool _isLoading = true;
  WordStats? _wordStats;
  Map<int, CategoryLevel> _levelProgress = {};
  String _currentTargetLanguage = '';

  @override
  void initState() {
    super.initState();
    _currentTargetLanguage = widget.targetLanguage;
    _loadLearningWords();
    _loadWordStats();
    _loadLevelProgress();
  }

  @override
  void didUpdateWidget(CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if target language has changed
    if (widget.targetLanguage != _currentTargetLanguage) {
      _currentTargetLanguage = widget.targetLanguage;
      _learningWords.clear();
      _wordStats = null;
      _levelProgress.clear();
      _loadLearningWords();
      _loadWordStats();
      _loadLevelProgress();
    }
  }

  Future<void> _loadLevelProgress() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
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

        // Filter by user's current target language
        final lessonTargetLanguage = data?['target_language']?.toString();

        return lessonCategory == widget.category['name'] && lessonTargetLanguage == widget.targetLanguage;
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

      // Build level progress data
      final Map<int, CategoryLevel> levels = {};
      for (int level = 1; level <= 3; level++) {
        final requiredLessons = CategoryLevelService.levelRequirements[level] ?? 3;
        final completedLessons = completedLessonsByLevel[level] ?? 0;
        final isLevelCompleted = completedLessons >= requiredLessons;

        levels[level] = CategoryLevel(
          currentLevel: level,
          completedLessons: completedLessons,
          requiredLessons: requiredLessons,
          isLevelCompleted: isLevelCompleted,
          canAccessNextLevel: level < 3 && isLevelCompleted,
        );
      }

      if (mounted) {
        setState(() {
          _levelProgress = levels;
        });
      }
    } catch (e) {
      print('Error loading level progress: $e');
    }
  }

  Future<void> _loadLearningWords() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${widget.targetLanguage}_words').doc(widget.category['name']).collection(widget.category['name']).get();

      final wordsData = snapshot.docs.map((doc) => Map<String, dynamic>.from(doc.data())).toList();
      if (mounted) {
        setState(() {
          _learningWords.addAll(wordsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading learning words: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWordStats() async {
    try {
      final stats = await WordStatsService.getCategoryWordStats(
        widget.category['name'],
        widget.targetLanguage,
        widget.category['words'] ?? [],
      );

      if (mounted) {
        setState(() {
          _wordStats = stats;
        });
      }
    } catch (e) {
      print('Error loading word stats: $e');
    }
  }

  void _showWordsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                // Create a sorted list of word indices
                final List<int> sortedIndices = List.generate((widget.category['words'] as List).length, (index) => index);

                // Sort the indices based on mastery status
                sortedIndices.sort((a, b) {
                  final wordA = (widget.category['words'] as List)[a].toString().toLowerCase();
                  final wordB = (widget.category['words'] as List)[b].toString().toLowerCase();

                  final matchingA = _learningWords.firstWhere(
                    (element) => element['word'] == wordA,
                    orElse: () => {},
                  );

                  final matchingB = _learningWords.firstWhere(
                    (element) => element['word'] == wordB,
                    orElse: () => {},
                  );

                  final scheduledDaysA = matchingA.isEmpty ? 0.0 : (matchingA['scheduledDays'] is int ? (matchingA['scheduledDays'] as int).toDouble() : (matchingA['scheduledDays'] as double? ?? 0.0));

                  final scheduledDaysB = matchingB.isEmpty ? 0.0 : (matchingB['scheduledDays'] is int ? (matchingB['scheduledDays'] as int).toDouble() : (matchingB['scheduledDays'] as double? ?? 0.0));

                  final isMasteredA = scheduledDaysA >= 100 || scheduledDaysA == -1;
                  final isMasteredB = scheduledDaysB >= 100 || scheduledDaysB == -1;

                  // Sort mastered words to the bottom
                  if (isMasteredA && !isMasteredB) {
                    return 1; // A is mastered, B is not, so A comes after B
                  } else if (!isMasteredA && isMasteredB) {
                    return -1; // A is not mastered, B is, so A comes before B
                  } else {
                    // Both are mastered or both are not mastered, sort alphabetically
                    return wordA.compareTo(wordB);
                  }
                });

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
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
                  child: Column(
                    children: [
                      // Modal header
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),

                      // Title
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              LessonConstants.getCategoryIcon(widget.category['name']),
                              color: _getCategoryColor(widget.category['name']),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Practise Words',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Instructions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          'Tap any word to see translation • Long press for options',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Column Headers
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Word',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  'Mastery',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Words List
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: sortedIndices.length,
                          itemBuilder: (context, i) {
                            final index = sortedIndices[i];
                            final word = (widget.category['words'] as List)[index].toString();
                            final nativeWord = (widget.nativeCategory['words'] as List)[index].toString();
                            return _buildSimpleWordItem(
                              word,
                              nativeWord,
                              onWordUpdated: () {
                                // Refresh the modal state when a word is updated
                                setModalState(() {});
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveScreenWrapper(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.category['name'],
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Hero Section with Category Overview
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getCategoryColor(widget.category['name']).withOpacity(0.1),
                            _getCategoryColor(widget.category['name']).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getCategoryColor(widget.category['name']).withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Category Icon and Title in a row
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  LessonConstants.getCategoryIcon(widget.category['name']),
                                  color: _getCategoryColor(widget.category['name']),
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  widget.category['name'],
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Word Stats (smaller, below level progress)
                          if (_wordStats != null) ...[
                            const SizedBox(height: 16),
                            _buildWordStatsSection(),
                            const SizedBox(height: 12),
                            _buildViewWordsButton(),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Levels Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.school_rounded,
                                  color: _getCategoryColor(widget.category['name']),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Learning Levels',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Level Cards
                          ...List.generate(3, (index) {
                            final levelNumber = index + 1;
                            final level = _levelProgress[levelNumber];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildLevelCard(levelNumber, level),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLevelCard(int levelNumber, CategoryLevel? level) {
    final colorScheme = Theme.of(context).colorScheme;
    final levelColor = CategoryLevelService.getLevelColor(levelNumber);
    final levelName = levelNumber == 1
        ? 'Beginner'
        : levelNumber == 2
            ? 'Intermediate'
            : 'Advanced';
    final requiredLessons = CategoryLevelService.levelRequirements[levelNumber] ?? 3;
    final completedLessons = level?.completedLessons ?? 0;
    final progressPercentage = requiredLessons > 0 ? (completedLessons / requiredLessons * 100).clamp(0, 100) : 0;

    // Check if level is unlocked
    final isLocked = _isLevelLocked(levelNumber);
    final lockedColor = colorScheme.onSurfaceVariant.withOpacity(0.3);

    return InkWell(
      onTap: isLocked
          ? () => _showLockedLevelDialog(levelNumber)
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LevelDetailScreen(
                    category: widget.category,
                    nativeCategory: widget.nativeCategory,
                    nativeLanguage: widget.nativeLanguage,
                    targetLanguage: widget.targetLanguage,
                    languageLevel: widget.languageLevel,
                    levelNumber: levelNumber,
                  ),
                ),
              ).then((_) {
                // Refresh level progress when returning
                _loadLevelProgress();
              });
            },
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLocked
                    ? [
                        lockedColor.withOpacity(0.1),
                        lockedColor.withOpacity(0.05),
                      ]
                    : [
                        levelColor.withOpacity(0.1),
                        levelColor.withOpacity(0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLocked ? lockedColor : levelColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                // Level Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isLocked ? lockedColor.withOpacity(0.15) : levelColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isLocked ? Icons.lock_rounded : CategoryLevelService.getLevelIcon(levelNumber),
                        color: isLocked ? lockedColor : levelColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Level $levelNumber: $levelName',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isLocked ? lockedColor : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isLocked ? 'Complete Level ${levelNumber - 1} to unlock' : '$completedLessons/$requiredLessons lessons completed',
                            style: TextStyle(
                              fontSize: 14,
                              color: isLocked ? lockedColor : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isLocked ? Icons.lock_rounded : Icons.arrow_forward_ios_rounded,
                      color: isLocked ? lockedColor : levelColor,
                      size: 16,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isLocked ? lockedColor : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          isLocked ? 'Locked' : '${progressPercentage.round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isLocked ? lockedColor : levelColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: isLocked ? 0 : progressPercentage / 100,
                        minHeight: 8,
                        backgroundColor: isLocked ? lockedColor.withOpacity(0.2) : levelColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(isLocked ? lockedColor : levelColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lock overlay
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 48,
                        color: lockedColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Locked',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: lockedColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isLevelLocked(int levelNumber) {
    if (levelNumber == 1) return false; // Level 1 is always unlocked

    // Check if previous level is completed
    final previousLevel = _levelProgress[levelNumber - 1];
    if (previousLevel == null) return true;

    return !previousLevel.isLevelCompleted;
  }

  int _getNextAvailableLevel(int fromLevel) {
    // Find the first level that's not completed, starting from level 1
    for (int level = 1; level < fromLevel; level++) {
      final levelProgress = _levelProgress[level];
      if (levelProgress == null || !levelProgress.isLevelCompleted) {
        return level;
      }
    }
    return fromLevel - 1; // Fallback to previous level
  }

  void _showLockedLevelDialog(int levelNumber) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextAvailableLevel = _getNextAvailableLevel(levelNumber);
    final nextAvailableLevelName = nextAvailableLevel == 1
        ? 'Beginner'
        : nextAvailableLevel == 2
            ? 'Intermediate'
            : 'Advanced';
    final nextLevel = _levelProgress[nextAvailableLevel];
    final requiredLessons = nextLevel?.requiredLessons ?? 3;
    final completedLessons = nextLevel?.completedLessons ?? 0;
    final remainingLessons = requiredLessons - completedLessons;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.lock_rounded,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Level Locked',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete Level $nextAvailableLevel ($nextAvailableLevelName) to unlock subsequent levels.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        remainingLessons == 1 ? 'You need to complete 1 more lesson in Level $nextAvailableLevel' : 'You need to complete $remainingLessons more lessons in Level $nextAvailableLevel',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'OK',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (remainingLessons > 0)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to the previous level
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LevelDetailScreen(
                        category: widget.category,
                        nativeCategory: widget.nativeCategory,
                        nativeLanguage: widget.nativeLanguage,
                        targetLanguage: widget.targetLanguage,
                        languageLevel: widget.languageLevel,
                        levelNumber: nextAvailableLevel,
                      ),
                    ),
                  ).then((_) {
                    _loadLevelProgress();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Go to Level $nextAvailableLevel',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildWordStatsSection() {
    if (_wordStats == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final totalWords = (widget.category['words'] as List).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Vocabulary Progress',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat('Mastered', _wordStats!.mastered, Colors.green.shade600),
              _buildProgressStat('Learning', _wordStats!.learning, Colors.orange.shade600),
              _buildProgressStat('New', totalWords - _wordStats!.mastered - _wordStats!.learning, colorScheme.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewWordsButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = _getCategoryColor(widget.category['name']);
    final totalWords = (widget.category['words'] as List).length;

    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _showWordsModal(context),
        icon: const Icon(
          Icons.visibility_rounded,
          size: 16,
          color: Colors.white,
        ),
        label: Text(
          'View All Words ($totalWords)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: categoryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildProgressStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleWordItem(String word, String nativeWord, {required Function() onWordUpdated}) {
    final colorScheme = Theme.of(context).colorScheme;
    final matching = _learningWords.firstWhere(
      (element) => element['word'] == word.toLowerCase(),
      orElse: () => {},
    );

    final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
    final reps = matching.isEmpty ? 0 : (matching['reps'] ?? 0);

    final isMastered = scheduledDays >= 100 || scheduledDays == -1;
    final isLearning = !isMastered && reps > 0;

    // Calculate progress percentage
    double progressValue;
    Color progressColor;

    if (isMastered) {
      progressValue = 1.0;
      progressColor = Colors.green;
    } else if (isLearning) {
      progressValue = scheduledDays / 100;
      progressColor = Colors.orange;
    } else {
      progressValue = 0.0;
      progressColor = colorScheme.onSurfaceVariant.withOpacity(0.3);
    }

    return InkWell(
      onTap: () => _showTranslationSheet(context, word, nativeWord),
      onLongPress: () => showMarkAsMasteredModal(
        context: context,
        word: word,
        categoryName: widget.category['name'],
        targetLanguage: widget.targetLanguage,
        learningWords: _learningWords,
        updateLearningWords: (updated) {
          setState(() => _learningWords
            ..clear()
            ..addAll(updated));
          onWordUpdated(); // Call the callback to refresh the modal
        },
        loadWordStats: () async {
          await _loadWordStats();
          onWordUpdated(); // Call the callback to refresh the modal
          return;
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
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
                word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Circular Progress Indicator
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 3,
                    backgroundColor: colorScheme.onSurfaceVariant.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onSurfaceVariant.withOpacity(0.1),
                    ),
                  ),
                  // Progress circle
                  CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                  // Center icon or percentage
                  Text(
                    isMastered ? '100%' : '${(progressValue * 100).round()}%',
                    style: TextStyle(
                      fontSize: isMastered ? 8 : 9,
                      fontWeight: isMastered ? FontWeight.w700 : FontWeight.w600,
                      color: progressColor,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colorScheme.onSurfaceVariant,
                      size: 18,
                    ),
                    Expanded(
                      child: Text(
                        nativeWord,
                        style: TextStyle(
                          fontSize: 20,
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

  // Helper method to generate colors based on category name
  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'at the coffee shop':
        return const Color(0xFF5D4037);
      case 'weather talk':
        return const Color(0xFF303F9F);
      case 'in the supermarket':
        return const Color(0xFF388E3C);
      case 'asking for directions':
        return const Color(0xFF1976D2);
      case 'making small talk':
        return const Color(0xFF00695C);
      case 'at the airport':
        return const Color(0xFF455A64);
      case 'at the restaurant':
        return const Color(0xFFD84315);
      case 'at the hotel':
        return const Color(0xFF4E342E);
      case 'at the doctor\'s office':
        return const Color(0xFFC62828);
      case 'public transportation':
        return const Color(0xFF7B1FA2);
      case 'shopping for clothes':
        return const Color(0xFFC2185B);
      case 'at the gym':
        return const Color(0xFFEF6C00);
      case 'at the bank':
        return const Color(0xFF512DA8);
      case 'at the post office':
        return const Color(0xFF00838F);
      case 'at the pharmacy':
        return const Color(0xFF0097A7);
      case 'at the park':
        return const Color(0xFF689F38);
      case 'at the beach':
        return const Color(0xFF0288D1);
      case 'at the library':
        return const Color(0xFF3949AB);
      case 'at the cinema':
        return const Color(0xFF5E35B1);
      case 'at the hair salon':
        return const Color(0xFFAD1457);
      case 'custom lesson':
        return const Color(0xFF546E7A);
      default:
        final int hashCode = categoryName.toLowerCase().hashCode;
        return Color((hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.6);
    }
  }
}

void showCenteredToast(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  final overlay = Overlay.of(context);

  // Dismiss any existing toast first
  if (_activeToastEntry != null) {
    _activeToastEntry!.remove();
    _activeToastEntry = null;
  }

  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );

  // Save reference to current toast
  _activeToastEntry = overlayEntry;
  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2), () {
    // Only remove if this is still the active toast
    if (_activeToastEntry == overlayEntry) {
      overlayEntry.remove();
      _activeToastEntry = null;
    }
  });
}
