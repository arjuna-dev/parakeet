import 'package:flutter/material.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/utils/lesson_constants.dart';

class CustomLessonForm extends StatefulWidget {
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;

  const CustomLessonForm({
    Key? key,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    this.isSmallScreen = false,
  }) : super(key: key);

  @override
  State<CustomLessonForm> createState() => _CustomLessonFormState();
}

class _CustomLessonFormState extends State<CustomLessonForm> {
  final TextEditingController _topicController = TextEditingController();
  final List<String> _selectedWords = [];
  bool _isCreatingCustomLesson = false;
  bool _isSuggestingRandom = false;

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  void _addWord(String word) {
    if (word.isEmpty) return;

    setState(() {
      if (_selectedWords.length < LessonConstants.maxWordsAllowed) {
        final normalizedWord = word.trim().toLowerCase();
        if (!_selectedWords.contains(normalizedWord)) {
          _selectedWords.add(normalizedWord);
        }
      }
    });
  }

  void _removeWord(String word) {
    setState(() {
      _selectedWords.remove(word);
    });
  }

  Future<void> _showAddWordDialog() async {
    final TextEditingController wordController = TextEditingController();
    String? wordValue;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add Word (${_selectedWords.length}/${LessonConstants.maxWordsAllowed})',
            style: const TextStyle(fontSize: 18),
          ),
          content: TextField(
            controller: wordController,
            decoration: const InputDecoration(
              hintText: 'Enter a word',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                wordValue = value;
                Navigator.pop(dialogContext);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (wordController.text.isNotEmpty) {
                  wordValue = wordController.text;
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    // Add the word after the dialog is closed and controller is disposed
    if (wordValue != null && wordValue!.isNotEmpty) {
      _addWord(wordValue!);
    }

    wordController.dispose();
  }

  Future<void> _createCustomLesson() async {
    await LessonService.createCustomLesson(
      context,
      _topicController.text.trim(),
      _selectedWords,
      widget.nativeLanguage,
      widget.targetLanguage,
      widget.languageLevel,
      (bool value) {
        setState(() {
          _isCreatingCustomLesson = value;
        });
      },
    );

    // Reset form if successful
    if (!_isCreatingCustomLesson) {
      _topicController.clear();
    }
  }

  Future<void> _suggestRandomLesson() async {
    setState(() {
      _isSuggestingRandom = true;
    });

    try {
      final result = await LessonService.suggestRandomLesson(
        widget.targetLanguage,
        widget.nativeLanguage,
      );

      setState(() {
        // Clear existing data
        _topicController.text = result['topic'] as String;
        _selectedWords.clear();

        // Add new words
        final wordsToLearn = (result['words_to_learn'] as List).cast<String>();
        for (var word in wordsToLearn) {
          if (_selectedWords.length < LessonConstants.maxWordsAllowed) {
            _selectedWords.add(word);
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get random suggestion: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSuggestingRandom = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: widget.isSmallScreen ? 8 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Input
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Topic',
                      style: TextStyle(
                        fontSize: widget.isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSuggestingRandom ? null : _suggestRandomLesson,
                      icon: _isSuggestingRandom
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Suggest Random'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        textStyle: TextStyle(fontSize: widget.isSmallScreen ? 12 : 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                    hintText: 'Enter a topic for your lesson',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 4),
                Text(
                  'Example: "Ordering food at a restaurant" or "Asking for directions"',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Words to Learn
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Words to Learn (${_selectedWords.length}/${LessonConstants.maxWordsAllowed})',
                      style: TextStyle(
                        fontSize: widget.isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: _selectedWords.length >= LessonConstants.maxWordsAllowed ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: _selectedWords.length >= LessonConstants.maxWordsAllowed ? null : _showAddWordDialog,
                      tooltip: 'Add word',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedWords.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Add up to 5 words you want to learn',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedWords.map((word) {
                      return Chip(
                        label: Text(word),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _removeWord(word),
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        side: BorderSide(
                          color: colorScheme.primary.withOpacity(0.2),
                        ),
                        labelStyle: TextStyle(
                          color: colorScheme.primary,
                        ),
                        deleteIconColor: colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Create Lesson Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isCreatingCustomLesson || _selectedWords.isEmpty || _topicController.text.trim().isEmpty ? null : _createCustomLesson,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isCreatingCustomLesson
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Create Custom Lesson',
                      style: TextStyle(
                        fontSize: widget.isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
