import 'package:flutter/material.dart';
import 'package:parakeet/screens/category_detail_screen.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:parakeet/services/word_stats_service.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CategoryList extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> nativeCategories;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;
  final bool isPremiumUser;

  const CategoryList({
    Key? key,
    required this.categories,
    required this.nativeCategories,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    this.isSmallScreen = false,
    this.isPremiumUser = false,
  }) : super(key: key);

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  int _visibleCategoriesCount = 4;
  final Map<String, WordStats> _categoryStats = {};
  final Set<String> _loadingStats = {};
  String _currentTargetLanguage = '';

  @override
  void initState() {
    super.initState();
    _currentTargetLanguage = widget.targetLanguage;
    _loadInitialCategoryStats();
  }

  @override
  void didUpdateWidget(CategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if target language has changed
    if (widget.targetLanguage != _currentTargetLanguage) {
      _currentTargetLanguage = widget.targetLanguage;
      _categoryStats.clear(); // Clear old stats
      _loadingStats.clear();
      _loadInitialCategoryStats(); // Reload with new language
    }
  }

  Future<void> _loadInitialCategoryStats() async {
    // Load stats for initially visible categories
    final visibleCategories = widget.categories.sublist(0, _visibleCategoriesCount > widget.categories.length ? widget.categories.length : _visibleCategoriesCount);

    for (var category in visibleCategories) {
      _loadCategoryStats(category['name']);
    }
  }

  Future<void> _loadCategoryStats(String categoryName) async {
    if (_loadingStats.contains(categoryName) || _categoryStats.containsKey(categoryName)) {
      return;
    }

    setState(() {
      _loadingStats.add(categoryName);
    });

    // Find the category to get its words
    final category = widget.categories.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => <String, Object>{'words': <Object>[]},
    );

    final stats = await WordStatsService.getCategoryWordStats(
      categoryName,
      widget.targetLanguage,
      category['words'] ?? [],
    );

    setState(() {
      _categoryStats[categoryName] = stats;
      _loadingStats.remove(categoryName);
    });
  }

  void _loadMoreCategories() {
    final newVisibleCount = _visibleCategoriesCount + 4;
    final actualNewCount = newVisibleCount > widget.categories.length ? widget.categories.length : newVisibleCount;

    // Load stats for newly visible categories
    if (actualNewCount > _visibleCategoriesCount) {
      for (int i = _visibleCategoriesCount; i < actualNewCount; i++) {
        if (i < widget.categories.length) {
          _loadCategoryStats(widget.categories[i]['name']);
        }
      }
    }

    setState(() {
      _visibleCategoriesCount = actualNewCount;
    });
  }

  void _handleStoreNavigation() {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.phone_android, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Mobile App Required'),
              ],
            ),
            content: const Text(
              'Please use the Parakeet mobile app to view and purchase premium features.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StoreView()),
      );
    }
  }

  bool _isCategoryLocked(int index) {
    // If user is premium, no categories are locked
    if (widget.isPremiumUser) {
      return false;
    }

    // Lock the last 10 categories or all categories after the 4th one
    // whichever is smaller (to avoid locking all categories if there are fewer than 14)
    final totalCategories = widget.categories.length;
    final maxUnlockedCategories = totalCategories > 10 ? totalCategories - 10 : 4;

    return index >= maxUnlockedCategories;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCategories = widget.categories.sublist(0, _visibleCategoriesCount > widget.categories.length ? widget.categories.length : _visibleCategoriesCount);
    final visibleNativeCategories = widget.nativeCategories.sublist(0, _visibleCategoriesCount > widget.nativeCategories.length ? widget.nativeCategories.length : _visibleCategoriesCount);

    return Column(
      children: [
        // Sticky header
        Container(
          width: double.infinity,
          color: colorScheme.surface,
          padding: EdgeInsets.fromLTRB(
            16,
            widget.isSmallScreen ? 16 : 20,
            16,
            20,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose your learning scenario and track your progress',
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

        // Scrollable content
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: widget.isSmallScreen ? 8 : 16,
            ),
            itemCount: visibleCategories.length + (_visibleCategoriesCount < widget.categories.length ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < visibleCategories.length) {
                final category = visibleCategories[index];
                final nativeCategory = visibleNativeCategories[index];
                final categoryName = category['name'];
                final stats = _categoryStats[categoryName];
                final isLocked = _isCategoryLocked(index);

                return Stack(
                  children: [
                    CategoryItemWithStats(
                      category: category,
                      onTap: isLocked ? () => _handleStoreNavigation() : () => _handleCategorySelection(context, category, nativeCategory),
                      isSmallScreen: widget.isSmallScreen,
                      stats: stats,
                      isLoading: _loadingStats.contains(categoryName),
                    ),

                    // Locked overlay for premium categories
                    if (isLocked)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _handleStoreNavigation(),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Premium Only',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      'Upgrade to unlock this category',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              } else {
                // This is the "More categories" button
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _loadMoreCategories,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'More categories',
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colorScheme.onSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  void _handleCategorySelection(BuildContext context, Map<String, dynamic> category, Map<String, dynamic> nativeCategory) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(
          category: category,
          nativeCategory: nativeCategory,
          nativeLanguage: widget.nativeLanguage,
          targetLanguage: widget.targetLanguage,
          languageLevel: widget.languageLevel,
        ),
      ),
    );
  }
}

class CategoryItemWithStats extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final bool isSmallScreen;
  final WordStats? stats;
  final bool isLoading;

  const CategoryItemWithStats({
    Key? key,
    required this.category,
    required this.onTap,
    this.isSmallScreen = false,
    this.stats,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 200,
          width: double.infinity,
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
                      center: const Alignment(0.5, 0.5),
                      radius: 0.8,
                      colors: [
                        _getCategoryColor(category['name'] as String).withOpacity(0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Category icon/image
              Positioned(
                right: 20,
                bottom: 20,
                child: Icon(
                  LessonConstants.getCategoryIcon(category['name'] as String),
                  color: _getCategoryColor(category['name'] as String),
                  size: 80,
                ),
              ),

              // Category title and stats
              Positioned(
                left: 20,
                top: 20,
                right: 20, // Full width minus padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and word count in a separate area
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category['name'] as String,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${category['words'].length ?? 0} words available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Stats below title area - this will not overlap with the icon
                    Padding(
                      padding: const EdgeInsets.only(right: 80), // Make room for the icon
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : stats != null
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 150,
                                    maxWidth: 200,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 6),
                                      // Using a fixed width container for the progress bar
                                      SizedBox(
                                        width: 180,
                                        child: _buildProgressBar(context, stats!),
                                      ),
                                      const SizedBox(height: 6),
                                      _buildLegend(context, stats!),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, WordStats stats) {
    // Get total words from category, not just from learning status
    final totalAvailableWords = category['words']?.length ?? 0;
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
                      color: Colors.green.shade600.withOpacity(0.8),
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
                      color: Colors.blue.shade600.withOpacity(0.8),
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
                      color: Colors.amber.shade600.withOpacity(0.8),
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
    final totalAvailableWords = category['words']?.length ?? 0;

    // Always include all three states
    final List<Widget> legendItems = [
      _buildLegendItem(context, stats.mastered, totalAvailableWords, 'Mastered', Colors.green.shade600.withOpacity(0.8)),
      _buildLegendItem(context, stats.learned, totalAvailableWords, 'Learned', Colors.blue.shade600.withOpacity(0.8)),
      _buildLegendItem(context, stats.learning, totalAvailableWords, 'Learning', Colors.amber.shade600.withOpacity(0.8)),
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
