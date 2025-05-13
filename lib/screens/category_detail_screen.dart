import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/widgets/library_screen/lesson_item.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/services/word_stats_service.dart';

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
  final HomeScreenModel _model = HomeScreenModel();
  Map<String, bool> _localFavorites = {};
  List<DocumentSnapshot> _categoryLessons = [];
  final List<Map<String, dynamic>> _learningWords = [];
  bool _isLoading = true;
  bool _wordsExpanded = false;
  WordStats? _wordStats;
  String _currentTargetLanguage = '';

  @override
  void initState() {
    super.initState();
    _currentTargetLanguage = widget.targetLanguage;
    _loadFavorites();
    _loadLearningWords();
    _loadWordStats();
  }

  @override
  void didUpdateWidget(CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if target language has changed
    if (widget.targetLanguage != _currentTargetLanguage) {
      _currentTargetLanguage = widget.targetLanguage;
      _learningWords.clear();
      _wordStats = null;
      _loadLearningWords();
      _loadWordStats();
      _refreshCategoryLessons(); // Refresh lessons when target language changes
    }
  }

  Future<void> _loadFavorites() async {
    try {
      await _model.loadAudioFiles();
      _loadCategoryLessons();
    } catch (e) {
      print('Error loading favorites: $e');
      _loadCategoryLessons();
    }
  }

  Future<void> _loadLearningWords() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${widget.targetLanguage}_words').doc(widget.category['name']).collection(widget.category['name']).get();

      final wordsData = snapshot.docs.map((doc) => doc.data()).toList();
      if (mounted) {
        setState(() {
          _learningWords.addAll(wordsData);
        });
      }
    } catch (e) {
      print('Error loading learning words: $e');
    }
  }

  Future<void> _loadWordStats() async {
    try {
      final stats = await WordStatsService.getCategoryWordStats(
        widget.category['name'],
        widget.targetLanguage,
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

  Future<void> _refreshCategoryLessons() async {
    await _loadCategoryLessons();
  }

  Future<void> _loadCategoryLessons() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();
      print('snapshot: ${snapshot.docs.map((doc) => doc.data())}');
      final filteredData = snapshot.docs.where((doc) => doc.data()['category'] == widget.category['name'] && doc.data()['target_language'] == widget.targetLanguage);
      print('filteredData: ${filteredData.map((doc) => doc.data())}');

      // Initialize _localFavorites map with current favorite state
      Map<String, bool> initialFavorites = {};
      for (var doc in filteredData) {
        String parentId = doc.reference.parent.parent!.id;
        String docId = doc.reference.id;
        String key = '$parentId-$docId';

        initialFavorites[key] = _model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId);
      }

      setState(() {
        _categoryLessons = filteredData.toList();
        _localFavorites = initialFavorites;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading category lessons: $e');
      setState(() => _isLoading = false);
    }
  }

  void _handleCreateNewLesson() {
    LessonService.createCategoryLesson(
      context,
      widget.category,
      widget.nativeLanguage,
      widget.targetLanguage,
      widget.languageLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return ResponsiveScreenWrapper(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.category['name'],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Info Section
                    Container(
                      margin: const EdgeInsets.all(16),
                      height: _wordStats != null ? 170 : 90,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Gradient overlay for visual effect
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: RadialGradient(
                                  center: const Alignment(1.2, 0.5),
                                  radius: 1.2,
                                  colors: [
                                    _getCategoryColor(widget.category['name']).withOpacity(0.5),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Category icon
                          Positioned(
                            right: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Icon(
                                LessonConstants.getCategoryIcon(widget.category['name']),
                                color: _getCategoryColor(widget.category['name']),
                                size: isSmallScreen ? 38 : 48,
                              ),
                            ),
                          ),

                          // Category info with stats
                          Positioned(
                            left: 16,
                            top: 0,
                            bottom: 0,
                            right: 70, // Leave space for the icon
                            child: Center(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Title and lesson count
                                  Text(
                                    '${_categoryLessons.length} ${_categoryLessons.length == 1 ? 'lesson' : 'lessons'}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(widget.category['words'] as List).length} words available',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13 : 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),

                                  // Add word stats display
                                  if (_wordStats != null) ...[
                                    const SizedBox(height: 16),
                                    // Constrain width but allow full height for the stats
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 150,
                                        maxWidth: 250,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Fixed width container
                                          SizedBox(
                                            width: 200,
                                            child: _buildProgressBar(context, _wordStats!),
                                          ),
                                          const SizedBox(height: 6),
                                          _buildLegend(context, _wordStats!),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Listing of words to learn in this category (fixed size with expand button)
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Gradient overlay for visual effect
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: RadialGradient(
                                  center: const Alignment(0.5, -0.5),
                                  radius: 1.2,
                                  colors: [
                                    colorScheme.primary.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Words to be learned',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Subtitle about tapping for translation
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                child: Text(
                                  'Tap any word to see its translation',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                              // Words grid - more compact
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: () {
                                    // Calculate item count based on sorted words
                                    final allWords = (widget.category['words'] as List).toList();
                                    final sortedWords = allWords.map((word) {
                                      final matching = _learningWords.firstWhere((element) => element['word'] == word.toString().toLowerCase(), orElse: () => {});
                                      final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
                                      return {
                                        'word': word.toString(),
                                        'score': scheduledDays,
                                      };
                                    }).toList()
                                      ..sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

                                    return _wordsExpanded ? sortedWords.length : min(4, sortedWords.length);
                                  }(),
                                  itemBuilder: (context, index) {
                                    // Get all words first
                                    final allWords = (widget.category['words'] as List).toList();

                                    // Create a list of all word data with scores for sorting
                                    final List<Map<String, dynamic>> allWordsWithScores = allWords.map((word) {
                                      final matching = _learningWords.firstWhere((element) => element['word'] == word.toString().toLowerCase(), orElse: () => {});
                                      final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
                                      return {
                                        'word': word.toString(),
                                        'score': scheduledDays,
                                        'index': allWords.indexOf(word), // Keep original index to match with native word
                                      };
                                    }).toList();

                                    // Sort all words by score (descending)
                                    allWordsWithScores.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

                                    // Then limit to display count
                                    final displayWords = allWordsWithScores.take(_wordsExpanded ? allWordsWithScores.length : 4).toList();

                                    // Use the sorted and limited data
                                    final word = displayWords[index]['word'] as String;
                                    final originalIndex = displayWords[index]['index'] as int;
                                    final nativeWord = (widget.nativeCategory['words'] as List)[originalIndex].toString();

                                    // Find matching word data for score calculation
                                    final matching = _learningWords.firstWhere((element) => element['word'] == word.toLowerCase(), orElse: () => {});

                                    // Compute stability based on matched data
                                    final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
                                    final learning = matching.isEmpty ? false : matching['reps'] > 0;
                                    final isLearned = scheduledDays >= 80;
                                    final isMastered = scheduledDays >= 100;

                                    return InkWell(
                                      onTap: () => showCenteredToast(context, nativeWord),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isLearned ? const Color.fromARGB(255, 136, 225, 139).withOpacity(0.5) : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    word,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: Colors.white,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMastered) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: Color.fromARGB(255, 136, 225, 139),
                                                  ),
                                                ] else if (isLearned) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 14,
                                                    color: Color.fromARGB(255, 136, 225, 139),
                                                  ),
                                                ]
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              () {
                                                if (isMastered) return 'Mastered';
                                                if (isLearned) return 'Learned';
                                                if (learning) return 'Learning';
                                                return 'Not started';
                                              }(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: () {
                                                  if (isMastered) return const Color.fromARGB(255, 136, 225, 139);
                                                  if (isLearned) return const Color.fromARGB(255, 136, 225, 139).withOpacity(0.8);
                                                  if (learning) return Colors.amber;
                                                  return Colors.white.withOpacity(0.6);
                                                }(),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            WordProgressBar(score: scheduledDays),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // See more/less button at the end
                              if ((widget.category['words'] as List).length > 5)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
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
                                          _wordsExpanded = !_wordsExpanded;
                                        });
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _wordsExpanded ? "See less" : "See more",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            _wordsExpanded ? Icons.expand_less : Icons.expand_more,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Words Being Learned Section

                    // Existing Lessons Section
                    if (_categoryLessons.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Saved Lessons',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._categoryLessons.map((doc) => LessonItem(
                            document: doc,
                            category: widget.category['name'],
                            isSmallScreen: isSmallScreen,
                            model: _model,
                            localFavorites: _localFavorites,
                            updateFavorites: (favorites) {
                              setState(() => _localFavorites = favorites);
                            },
                            onDeleteComplete: () {
                              setState(() {
                                _refreshCategoryLessons();
                              });
                            },
                          )),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
        bottomSheet: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: _handleCreateNewLesson,
              icon: const Icon(Icons.add),
              label: const Text('Create New Lesson'),
              style: FilledButton.styleFrom(
                minimumSize: Size(double.infinity, isSmallScreen ? 40 : 48),
              ),
            ),
          ),
        ),
        bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
      ),
    );
  }

  // Helper method to generate colors based on category name
  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'at the coffee shop':
        return Colors.brown;
      case 'in the library':
        return Colors.blue;
      case 'weather talk':
        return Colors.indigo;
      case 'making small talk':
        return Colors.teal;
      default:
        // Generate a color based on the first letter of the category name
        final int hashCode = categoryName.toLowerCase().hashCode;
        return Color((hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.8);
    }
  }

  Widget _buildProgressBar(BuildContext context, WordStats stats) {
    // Get total words from category, not just from learning status
    final totalAvailableWords = (widget.category['words'] as List).length;
    const barHeight = 12.0;

    // Handle edge case of no words
    if (totalAvailableWords == 0) {
      return SizedBox(
        height: barHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }

    // Calculate proportions based on total available words
    final masteredWidth = totalAvailableWords > 0 ? stats.mastered / totalAvailableWords : 0.0;
    final learnedWidth = totalAvailableWords > 0 ? stats.learned / totalAvailableWords : 0.0;
    final learningWidth = totalAvailableWords > 0 ? stats.learning / totalAvailableWords : 0.0;

    return SizedBox(
      height: barHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Mastered (green)
              if (masteredWidth > 0)
                SizedBox(
                  width: constraints.maxWidth * masteredWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(6),
                        bottomLeft: const Radius.circular(6),
                        topRight: learnedWidth == 0 && learningWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        bottomRight: learnedWidth == 0 && learningWidth == 0 ? const Radius.circular(6) : Radius.zero,
                      ),
                    ),
                  ),
                ),
              // Learned (blue)
              if (learnedWidth > 0)
                SizedBox(
                  width: constraints.maxWidth * learnedWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: masteredWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        bottomLeft: masteredWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        topRight: learningWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        bottomRight: learningWidth == 0 ? const Radius.circular(6) : Radius.zero,
                      ),
                    ),
                  ),
                ),
              // Learning (amber)
              if (learningWidth > 0)
                SizedBox(
                  width: constraints.maxWidth * learningWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.only(
                        topLeft: masteredWidth == 0 && learnedWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        bottomLeft: masteredWidth == 0 && learnedWidth == 0 ? const Radius.circular(6) : Radius.zero,
                        topRight: const Radius.circular(6),
                        bottomRight: const Radius.circular(6),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLegend(BuildContext context, WordStats stats) {
    // Get total words from category
    final totalAvailableWords = (widget.category['words'] as List).length;

    // Always include all three states
    final List<Widget> legendItems = [
      _buildLegendItem(context, stats.mastered, totalAvailableWords, 'Mastered', Colors.green),
      _buildLegendItem(context, stats.learned, totalAvailableWords, 'Learned', Colors.blue),
      _buildLegendItem(context, stats.learning, totalAvailableWords, 'Learning', Colors.amber),
    ];

    // Split items into rows of 2
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            legendItems[0],
            const SizedBox(width: 16),
            legendItems[1],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            legendItems[2],
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(BuildContext context, int count, int total, String label, Color color) {
    // Calculate percentage - avoid division by zero
    final percentage = total > 0 ? (count / total * 100).round() : 0;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$percentage% $label',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

class WordProgressBar extends StatelessWidget {
  final dynamic score;
  final int learnedScore = 100;
  const WordProgressBar({required this.score, super.key});

  double get progress {
    // Convert score to double safely
    final doubleScore = score is int ? score.toDouble() : (score is double ? score : 0.0);
    return (doubleScore.clamp(0, learnedScore)) / learnedScore;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Convert score to double safely
    final doubleScore = score is int ? score.toDouble() : (score is double ? score : 0.0);
    final progressColor = doubleScore >= 100 ? const Color.fromARGB(255, 136, 225, 139) : colorScheme.primary;
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color?>(progressColor),
        ),
      ),
    );
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
