import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/widgets/library_screen/lesson_item.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/main.dart';

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
  List<String> _learningWords = [];
  bool _isLoading = true;
  bool _showAllWords = false;

  @override
  void initState() {
    super.initState();
    _loadCategoryLessons();
    _loadLearningWords();
  }

  Future<void> _loadLearningWords() async {
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${widget.targetLanguage}_words').doc(widget.category['name']).collection(widget.category['name']).get();

      setState(() {
        _learningWords = snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      print('Error loading learning words: $e');
    }
  }

  Future<void> _loadCategoryLessons() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();
      print('snapshot: ${snapshot.docs.map((doc) => doc.data())}');
      final filteredData = snapshot.docs.where((doc) => doc.data()['category'] == widget.category['name']);
      print('filteredData: ${filteredData.map((doc) => doc.data())}');

      setState(() {
        _categoryLessons = filteredData.toList();
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

  List<String> get _displayedWords {
    if (_showAllWords) return _learningWords;
    // Calculate how many words fit in 2 rows (assuming ~4 words per row)
    return _learningWords.take(5).toList();
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      // color: colorScheme.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LessonConstants.getCategoryIcon(widget.category['name']),
                          color: colorScheme.primary,
                          size: isSmallScreen ? 24 : 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_categoryLessons.length} ${_categoryLessons.length == 1 ? 'lesson' : 'lessons'}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(widget.category['words'] as List).length} words available',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Listing of words to learn in this category
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      // color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      color: colorScheme.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GridView.count(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                      children: (widget.category['words'] as List).asMap().entries.map((entry) {
                        final index = entry.key;
                        final word = entry.value.toString();
                        final nativeWord = (widget.nativeCategory['words'] as List)[index].toString();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                                backgroundColor: colorScheme.surfaceContainer,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => showCenteredToast(context, nativeWord),
                              child: Text(
                                word,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6), // increased space between word and progress bar
                            WordProgressBar(score: 29),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  // Create New Lesson Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _handleCreateNewLesson,
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Lesson'),
                      style: FilledButton.styleFrom(
                        minimumSize: Size(double.infinity, isSmallScreen ? 40 : 48),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Words Being Learned Section
                  if (_learningWords.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Words You\'re Learning',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _displayedWords
                                .map((word) => Chip(
                                      label: Text(
                                        word,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 14,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      backgroundColor: colorScheme.surfaceContainerHighest,
                                    ))
                                .toList(),
                          ),
                          if (_learningWords.length > 5) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllWords = !_showAllWords;
                                });
                              },
                              child: Text(
                                _showAllWords ? 'Show Less' : 'Show More',
                                style: TextStyle(
                                  color: colorScheme.primary,
                                  fontSize: isSmallScreen ? 12 : 14,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Existing Lessons Section
                  if (_categoryLessons.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Existing Lessons',
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
                          onDelete: (doc) {
                            setState(() {
                              _categoryLessons.remove(doc);
                            });
                          },
                        )),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
    ));
  }
}

class WordProgressBar extends StatelessWidget {
  final int score;
  const WordProgressBar({required this.score, super.key});

  double get progress => (score.clamp(0, 30)) / 30;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: 0.5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color?>(colorScheme.primary),
        ),
      ),
    );
  }
}

void showCenteredToast(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  final overlay = Overlay.of(context);
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

  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2), () {
    overlayEntry.remove();
  });
}
