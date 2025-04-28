import 'package:flutter/material.dart';
import 'package:parakeet/widgets/create_lesson_screen/category_item.dart';
import 'package:parakeet/screens/category_detail_screen.dart';

class CategoryList extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> nativeCategories;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;

  const CategoryList({
    Key? key,
    required this.categories,
    required this.nativeCategories,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    this.isSmallScreen = false,
  }) : super(key: key);

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  int _visibleCategoriesCount = 4;

  void _loadMoreCategories() {
    setState(() {
      _visibleCategoriesCount = _visibleCategoriesCount + 4;
      if (_visibleCategoriesCount > widget.categories.length) {
        _visibleCategoriesCount = widget.categories.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCategories = widget.categories.sublist(0, _visibleCategoriesCount > widget.categories.length ? widget.categories.length : _visibleCategoriesCount);
    final visibleNativeCategories = widget.nativeCategories.sublist(0, _visibleCategoriesCount > widget.nativeCategories.length ? widget.nativeCategories.length : _visibleCategoriesCount);

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: widget.isSmallScreen ? 8 : 16,
      ),
      itemCount: visibleCategories.length + (_visibleCategoriesCount < widget.categories.length ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < visibleCategories.length) {
          final category = visibleCategories[index];
          final nativeCategory = visibleNativeCategories[index];
          return CategoryItem(
            category: category,
            onTap: () => _handleCategorySelection(context, category, nativeCategory),
            isSmallScreen: widget.isSmallScreen,
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
