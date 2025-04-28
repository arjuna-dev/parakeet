import 'package:flutter/material.dart';
import 'package:parakeet/utils/lesson_constants.dart';

class CategoryItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final VoidCallback onTap;
  final bool isSmallScreen;

  const CategoryItem({
    Key? key,
    required this.category,
    required this.onTap,
    this.isSmallScreen = false,
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
          height: 180,
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

              // Category icon/image (could be replaced with actual illustrations)
              Positioned(
                right: 20,
                bottom: 20,
                child: Icon(
                  LessonConstants.getCategoryIcon(category['name'] as String),
                  color: _getCategoryColor(category['name'] as String),
                  size: 80,
                ),
              ),

              // Category title
              Positioned(
                left: 20,
                bottom: 20,
                child: Text(
                  category['name'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
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
