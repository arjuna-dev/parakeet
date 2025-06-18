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

  static Widget buildNowPlayingList(BuildContext context, HomeScreenModel model, VoidCallback onReload) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return model.nowPlayingFiles.isEmpty
        ? EmptyStateView(
            icon: Icons.headphones_outlined,
            message: 'Start playing audio lessons to see them here! 🎧',
            additionalWidget: null,
            isSmallScreen: isSmallScreen,
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
            itemCount: model.nowPlayingFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.nowPlayingFiles[index];
              return LessonCard(
                audioFile: audioFile,
                onReload: onReload,
                isSmallScreen: isSmallScreen,
              );
            },
          );
  }

  static Widget buildFavoritesList(BuildContext context, HomeScreenModel model, VoidCallback onReload) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return model.favoriteAudioFiles.isEmpty
        ? EmptyStateView(
            icon: Icons.favorite_outline,
            message: 'Nothing here yet 😅.',
            additionalWidget: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: 'Create a lesson',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushReplacementNamed(context, '/create_lesson');
                      },
                  ),
                  const TextSpan(text: ' to add it to your favorite list!'),
                ],
              ),
            ),
            isSmallScreen: isSmallScreen,
          )
        : ListView.builder(
            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
            itemCount: model.favoriteAudioFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.favoriteAudioFiles[index];
              return LessonCard(
                audioFile: audioFile,
                onReload: onReload,
                isSmallScreen: isSmallScreen,
              );
            },
          );
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
  @override
  void initState() {
    super.initState();
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

    return Column(
      children: [
        // Category Filter
        if (widget.model.availableCategories.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.model.selectedCategory,
                      hint: Text(
                        'All Categories',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
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
                                  fontSize: 14,
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
                                      fontSize: 14,
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
                  icon: widget.model.selectedCategory != null ? Icons.search_off_rounded : Icons.school_outlined,
                  message: widget.model.selectedCategory != null ? 'No lessons found for "${widget.model.selectedCategory}" 🔍' : 'No lessons created yet 📚',
                  additionalWidget: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: widget.model.selectedCategory != null ? 'Try selecting a different category or ' : '',
                        ),
                        TextSpan(
                          text: widget.model.selectedCategory != null ? 'create a new lesson' : 'Create your first lesson',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.pushReplacementNamed(context, '/create_lesson');
                            },
                        ),
                        TextSpan(
                          text: widget.model.selectedCategory != null ? '!' : ' to get started!',
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
    );
  }
}
