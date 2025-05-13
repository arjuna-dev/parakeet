import 'package:flutter/material.dart';
import 'package:parakeet/services/lesson_detail_service.dart';

class LessonDetailContent extends StatelessWidget {
  final String category;
  final String title;
  final String topic;
  final List<dynamic> wordsToLearn;
  final List<String> allWords;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final String length;
  final bool isGeneratingLesson;
  final int maxWordsAllowed;
  final Function(List<String>) onWordsChanged;
  final Function(bool) setIsGeneratingLesson;

  const LessonDetailContent({
    Key? key,
    required this.category,
    required this.title,
    required this.topic,
    required this.wordsToLearn,
    required this.allWords,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.length,
    required this.isGeneratingLesson,
    required this.maxWordsAllowed,
    required this.onWordsChanged,
    required this.setIsGeneratingLesson,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final textScaleFactor = isSmallScreen ? 0.95 : 1.05;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row with Category
          Row(
            children: [
              // Category Container
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Category',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13 * textScaleFactor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category,
                        style: TextStyle(
                          fontSize: 17 * textScaleFactor,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title Section
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Topic Section
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            height: isSmallScreen ? 100 : 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      topic,
                      style: TextStyle(
                        fontSize: 15 * textScaleFactor,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Words to Repeat Section (without Edit button)
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Words to learn (${wordsToLearn.length}/$maxWordsAllowed)',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13 * textScaleFactor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: wordsToLearn
                      .map((word) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.primary.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              word.toLowerCase(),
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 14 * textScaleFactor,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start Lesson Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isGeneratingLesson || wordsToLearn.isEmpty
                    ? null // Disable button while generating or if no words selected
                    : () => LessonDetailService.startLesson(
                          context: context,
                          topic: topic,
                          wordsToLearn: wordsToLearn,
                          nativeLanguage: nativeLanguage,
                          targetLanguage: targetLanguage,
                          languageLevel: languageLevel,
                          length: length,
                          category: category,
                          title: title,
                          setIsGeneratingLesson: setIsGeneratingLesson,
                        ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Start Lesson',
                  style: TextStyle(
                    fontSize: 17 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
