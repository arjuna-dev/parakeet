import 'package:flutter/material.dart';
import 'package:parakeet/widgets/create_lesson_screen/category_item.dart';
import 'package:parakeet/screens/category_detail_screen.dart';

class CategoryList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 16,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final nativeCategory = nativeCategories[index];
        return CategoryItem(
          category: category,
          onTap: () => _handleCategorySelection(context, category, nativeCategory),
          isSmallScreen: isSmallScreen,
        );
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
          nativeLanguage: nativeLanguage,
          targetLanguage: targetLanguage,
          languageLevel: languageLevel,
        ),
      ),
    );
  }
}
