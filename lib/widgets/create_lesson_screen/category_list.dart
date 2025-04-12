import 'package:flutter/material.dart';
import 'package:parakeet/widgets/create_lesson_screen/category_item.dart';
import 'package:parakeet/screens/category_detail_screen.dart';

class CategoryList extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;

  const CategoryList({
    Key? key,
    required this.categories,
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
        return CategoryItem(
          category: category,
          onTap: () => _handleCategorySelection(context, category),
          isSmallScreen: isSmallScreen,
        );
      },
    );
  }

  void _handleCategorySelection(BuildContext context, Map<String, dynamic> category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(
          category: category,
          nativeLanguage: nativeLanguage,
          targetLanguage: targetLanguage,
          languageLevel: languageLevel,
        ),
      ),
    );
  }
}
