import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/widgets/home_screen/empty_state_view.dart';
import 'package:parakeet/widgets/home_screen/lesson_card.dart';
import 'package:parakeet/utils/category_icons.dart';

class HomeScreenService {
  static Widget buildAllLessonsList(BuildContext context, HomeScreenModel model, VoidCallback onReload) {
    return _AllLessonsListWidget(model: model, onReload: onReload);
  }
}

class _AllLessonsListWidget extends StatefulWidget {
  final HomeScreenModel model;
  final VoidCallback onReload;

  const _AllLessonsListWidget({
    required this.model,
    required this.onReload,
  });

  @override
  State<_AllLessonsListWidget> createState() => _AllLessonsListWidgetState();
}

class _AllLessonsListWidgetState extends State<_AllLessonsListWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      widget.model.setSearchQuery(_searchController.text);
      setState(() {}); // Trigger rebuild to update clear button visibility
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _getEmptyStateMessage() {
    final hasSearch = widget.model.searchQuery.isNotEmpty;
    final hasCategory = widget.model.selectedCategory != null;

    if (hasSearch && hasCategory) {
      return 'No lessons found for "${widget.model.selectedCategory}" with "${widget.model.searchQuery}" 🔍';
    } else if (hasSearch) {
      return 'No lessons found for "${widget.model.searchQuery}" 🔍';
    } else if (hasCategory) {
      return 'No lessons found for "${widget.model.selectedCategory}" 🔍';
    } else {
      return 'No lessons created yet 📚';
    }
  }

  String _getAdditionalWidgetPrefix() {
    final hasSearch = widget.model.searchQuery.isNotEmpty;
    final hasCategory = widget.model.selectedCategory != null;

    if (hasSearch && hasCategory) {
      return 'Try changing your search or category, or ';
    } else if (hasSearch) {
      return 'Try a different search term or ';
    } else if (hasCategory) {
      return 'Try selecting a different category or ';
    } else {
      return '';
    }
  }

  String _getAdditionalWidgetLinkText() {
    final hasSearch = widget.model.searchQuery.isNotEmpty;
    final hasCategory = widget.model.selectedCategory != null;

    if (hasSearch || hasCategory) {
      return 'create a new lesson';
    } else {
      return 'Create your first lesson';
    }
  }

  String _getAdditionalWidgetSuffix() {
    final hasSearch = widget.model.searchQuery.isNotEmpty;
    final hasCategory = widget.model.selectedCategory != null;

    if (hasSearch || hasCategory) {
      return '!';
    } else {
      return ' to get started!';
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside search field
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: [
          // Search Bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search lessons, words, or content...',
                hintStyle: TextStyle(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                isDense: true,
              ),
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _searchFocusNode.unfocus();
              },
            ),
          ),

          // Category Filter
          if (widget.model.availableCategories.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.model.selectedCategory,
                        hint: Text(
                          'All Categories',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.apps_rounded,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'All Categories',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...widget.model.availableCategories.map((category) {
                            final categoryColor = _getCategoryColor(category);
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Row(
                                children: [
                                  Icon(
                                    CategoryIcons.getCategoryIcon(category),
                                    size: 16,
                                    color: categoryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? value) {
                          widget.model.setSelectedCategory(value);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Lessons List
          Expanded(
            child: widget.model.filteredLessons.isEmpty
                ? EmptyStateView(
                    icon: (widget.model.searchQuery.isNotEmpty || widget.model.selectedCategory != null) ? Icons.search_off_rounded : Icons.school_outlined,
                    message: _getEmptyStateMessage(),
                    additionalWidget: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: _getAdditionalWidgetPrefix(),
                          ),
                          TextSpan(
                            text: _getAdditionalWidgetLinkText(),
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // Remove automatic navigation - user can use bottom nav instead
                                // Navigator.pushReplacementNamed(context, '/create_lesson');
                              },
                          ),
                          TextSpan(
                            text: _getAdditionalWidgetSuffix(),
                          ),
                        ],
                      ),
                    ),
                    isSmallScreen: isSmallScreen,
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                    itemCount: widget.model.filteredLessons.length,
                    itemBuilder: (context, index) {
                      final audioFile = widget.model.filteredLessons[index];
                      return LessonCard(
                        audioFile: audioFile,
                        onReload: widget.onReload,
                        isSmallScreen: isSmallScreen,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
