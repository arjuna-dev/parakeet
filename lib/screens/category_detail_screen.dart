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
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;

  const CategoryDetailScreen({
    Key? key,
    required this.category,
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
                      color: colorScheme.primaryContainer.withOpacity(0.7),
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
