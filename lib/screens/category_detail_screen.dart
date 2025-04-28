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
  final List<Map<String, dynamic>> _learningWords = [];
  bool _isLoading = true;
  bool _wordsExpanded = false; // new state variable for expansion

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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

  Future<void> _refreshCategoryLessons() async {
    await _loadCategoryLessons();
  }

  Future<void> _loadCategoryLessons() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();
      print('snapshot: ${snapshot.docs.map((doc) => doc.data())}');
      final filteredData = snapshot.docs.where((doc) => doc.data()['category'] == widget.category['name']);
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
                      height: 90,
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

                          // Category info
                          Positioned(
                            left: 16,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
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
                                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Words to Learn',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
                                    childAspectRatio: 2.8,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: (widget.category['words'] as List).take(_wordsExpanded ? (widget.category['words'] as List).length : 5).length,
                                  itemBuilder: (context, index) {
                                    final words = (widget.category['words'] as List).take(_wordsExpanded ? (widget.category['words'] as List).length : 5).toList();
                                    final word = words[index].toString();
                                    final nativeWord = (widget.nativeCategory['words'] as List)[index].toString();

                                    // Find matching word data for score calculation
                                    final matching = _learningWords.firstWhere((element) => element['word'] == word.toLowerCase(), orElse: () => {});

                                    // Compute stability based on matched data
                                    final stabilityVal = matching.isEmpty ? 0.0 : matching['stability'];
                                    final isLearned = stabilityVal > 365;

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
                                                Icon(
                                                  Icons.info_outline,
                                                  size: 14,
                                                  color: Colors.white.withOpacity(0.6),
                                                ),
                                                const SizedBox(width: 4),
                                                if (isLearned)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    size: 14,
                                                    color: Color.fromARGB(255, 136, 225, 139),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            WordProgressBar(score: stabilityVal),
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
        return Colors.pink;
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
}

class WordProgressBar extends StatelessWidget {
  final double score;
  final int learnedScore = 100;
  const WordProgressBar({required this.score, super.key});

  double get progress => (score.clamp(0, learnedScore)) / learnedScore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Changed: set progress color to green if score >= 100, else use primary color
    final progressColor = score >= 100 ? const Color.fromARGB(255, 136, 225, 139) : colorScheme.primary;
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
