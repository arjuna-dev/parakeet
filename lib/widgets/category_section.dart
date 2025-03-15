import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/utils/category_icons.dart';
import 'package:parakeet/widgets/lesson_item.dart';
import 'package:parakeet/services/home_screen_model.dart';

class CategorySection extends StatelessWidget {
  final String category;
  final List<DocumentSnapshot> documents;
  final bool isExpanded;
  final bool isSmallScreen;
  final Function(String) onToggleExpansion;
  final HomeScreenModel model;
  final Map<String, bool> localFavorites;
  final Function(Map<String, bool>) updateFavorites;
  final Function(DocumentSnapshot) onDeleteDocument;

  const CategorySection({
    Key? key,
    required this.category,
    required this.documents,
    required this.isExpanded,
    required this.isSmallScreen,
    required this.onToggleExpansion,
    required this.model,
    required this.localFavorites,
    required this.updateFavorites,
    required this.onDeleteDocument,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category header
        InkWell(
          onTap: () => onToggleExpansion(category),
          child: Container(
            margin: EdgeInsets.only(
              bottom: isSmallScreen ? 8 : 12,
            ),
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 8 : 12,
              horizontal: isSmallScreen ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  CategoryIcons.getCategoryIcon(category),
                  color: colorScheme.primary,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    category,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 16 : 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Text(
                  '${documents.length} ${documents.length == 1 ? 'lesson' : 'lessons'}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.primary,
                  size: isSmallScreen ? 20 : 24,
                ),
              ],
            ),
          ),
        ),

        // Category lessons (collapsible)
        if (isExpanded)
          ...documents.map((document) => LessonItem(
                document: document,
                category: category,
                isSmallScreen: isSmallScreen,
                model: model,
                localFavorites: localFavorites,
                updateFavorites: updateFavorites,
                onDelete: onDeleteDocument,
              )),
      ],
    );
  }
}
