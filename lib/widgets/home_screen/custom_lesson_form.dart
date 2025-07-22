import 'package:flutter/material.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:parakeet/utils/example_scenarios.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class CustomLessonForm extends StatefulWidget {
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;
  final bool isLoading;
  final VoidCallback? onLessonCreated;
  final Function(String topic, List<String> words)? onLessonStarted;

  const CustomLessonForm({
    Key? key,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    this.isSmallScreen = false,
    this.isLoading = false,
    this.onLessonCreated,
    this.onLessonStarted,
  }) : super(key: key);

  @override
  State<CustomLessonForm> createState() => _CustomLessonFormState();
}

class _CustomLessonFormState extends State<CustomLessonForm> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _wordController = TextEditingController();
  final FocusNode _topicFocusNode = FocusNode();
  final FocusNode _wordFocusNode = FocusNode();
  final List<String> _selectedWords = [];
  bool _isSuggestingRandom = false;
  bool _showWordInput = false;
  late AnalyticsManager analyticsManager;

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
    // Listen to topic changes to update button state
    _topicController.addListener(_updateButtonState);
    // Populate fields with a random scenario on load
    _populateRandomScenario();
  }

  void _initializeAnalytics() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      analyticsManager = AnalyticsManager(user.uid);
    }
  }

  void _populateRandomScenario() {
    try {
      // Get a random scenario from the dictionary
      final random = Random();
      final scenarios = scenarioKeywords.keys.toList();
      final randomScenario = scenarios[random.nextInt(scenarios.length)];
      final words = scenarioKeywords[randomScenario]!;

      // Populate the topic field
      _topicController.text = randomScenario;

      // Populate the words to learn (up to the max allowed)
      _selectedWords.clear();
      for (var word in words) {
        if (_selectedWords.length < LessonConstants.maxWordsAllowed) {
          _selectedWords.add(word);
        }
      }
    } catch (e) {
      // If there's an error, just leave the fields empty
      debugPrint('Failed to populate random scenario: $e');
    }
  }

  @override
  void dispose() {
    _topicController.dispose();
    _wordController.dispose();
    _topicFocusNode.dispose();
    _wordFocusNode.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    if (mounted) {
      setState(() {
        // This will trigger a rebuild and update the button state
      });
    }
  }

  bool get _canCreateLesson {
    return _topicController.text.trim().isNotEmpty && _selectedWords.isNotEmpty;
  }

  void _addWord(String word) {
    if (word.trim().isEmpty) return;

    final normalizedWord = word.trim().toLowerCase();
    if (mounted) {
      setState(() {
        if (_selectedWords.length < LessonConstants.maxWordsAllowed && !_selectedWords.contains(normalizedWord)) {
          _selectedWords.add(normalizedWord);
          analyticsManager.storeAction('custom_lesson_word_added', normalizedWord);
        }
      });
    }
  }

  void _removeWord(String word) {
    if (mounted) {
      setState(() {
        _selectedWords.remove(word);
      });
    }
  }

  void _addWordFromInput() {
    final word = _wordController.text.trim();
    if (word.isNotEmpty) {
      _addWord(word);
      _wordController.clear();
      if (_selectedWords.length >= LessonConstants.maxWordsAllowed) {
        _hideWordInput();
      }
    }
  }

  void _hideWordInput() {
    if (mounted) {
      setState(() {
        _showWordInput = false;
      });
    }
    _wordController.clear();
    _wordFocusNode.unfocus();
  }

  void _dismissKeyboard() {
    _topicFocusNode.unfocus();
    _wordFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _createCustomLesson() async {
    // Validate inputs
    if (_topicController.text.trim().isEmpty) {
      analyticsManager.storeAction('custom_lesson_validation_failed_empty_topic');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic for your lesson'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedWords.isEmpty) {
      analyticsManager.storeAction('custom_lesson_validation_failed_no_words');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one word to learn'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Track successful lesson creation
    analyticsManager.storeAction('custom_lesson_generate_button_pressed', '${_topicController.text.trim()}|${_selectedWords.length} words');

    // Call the callback to start lesson creation in parent
    if (widget.onLessonStarted != null) {
      widget.onLessonStarted!(_topicController.text.trim(), _selectedWords);
    }
  }

  Future<void> _suggestRandomLesson() async {
    if (mounted) {
      setState(() {
        _isSuggestingRandom = true;
      });
    }

    try {
      // Get a random scenario from the dictionary
      final random = Random();
      final scenarios = scenarioKeywords.keys.toList();
      final randomScenario = scenarios[random.nextInt(scenarios.length)];
      final words = scenarioKeywords[randomScenario]!;

      if (mounted) {
        setState(() {
          // Clear existing data
          _topicController.text = randomScenario;
          _selectedWords.clear();

          // Add words from the scenario (up to the max allowed)
          for (var word in words) {
            if (_selectedWords.length < LessonConstants.maxWordsAllowed) {
              _selectedWords.add(word);
            }
          }
        });
      }
    } catch (e) {
      analyticsManager.storeAction('custom_lesson_random_suggestion_failed', e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get random suggestion: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSuggestingRandom = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 5,
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
                        padding: const EdgeInsets.all(12),
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
                                  onPressed: _isSuggestingRandom
                                      ? null
                                      : () {
                                          analyticsManager.storeAction('custom_lesson_generate_random_button_pressed');
                                          _suggestRandomLesson();
                                        },
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
                                  label: const Text('Generate Random'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    textStyle: TextStyle(fontSize: widget.isSmallScreen ? 12 : 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextField(
                              controller: _topicController,
                              focusNode: _topicFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Enter a topic for your lesson',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                                suffixIcon: _topicController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          analyticsManager.storeAction('custom_lesson_topic_clear_button_pressed');
                                          _topicController.clear();
                                          _updateButtonState();
                                        },
                                      )
                                    : null,
                              ),
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _dismissKeyboard(),
                              style: TextStyle(
                                color: colorScheme.tertiary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You can enter your own in any language.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flexible spacer
                      const Expanded(
                        flex: 1,
                        child: SizedBox(height: 16),
                      ),

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
                                Expanded(
                                  child: Text(
                                    'Words to Learn (${_selectedWords.length}/${LessonConstants.maxWordsAllowed})',
                                    style: TextStyle(
                                      fontSize: widget.isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (!_showWordInput)
                                  IconButton(
                                    icon: Icon(
                                      Icons.add_circle,
                                      color: _selectedWords.length >= LessonConstants.maxWordsAllowed ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.primary,
                                      size: 24,
                                    ),
                                    onPressed: _selectedWords.length >= LessonConstants.maxWordsAllowed
                                        ? null
                                        : () {
                                            analyticsManager.storeAction('custom_lesson_add_word_button_pressed');
                                            if (mounted) {
                                              setState(() {
                                                _showWordInput = true;
                                              });
                                            }
                                            WidgetsBinding.instance.addPostFrameCallback((_) {
                                              _wordFocusNode.requestFocus();
                                              // Ensure the input field scrolls into view
                                              Future.delayed(const Duration(milliseconds: 300), () {
                                                if (mounted && _wordFocusNode.context != null) {
                                                  Scrollable.ensureVisible(
                                                    _wordFocusNode.context!,
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                }
                                              });
                                            });
                                          },
                                    tooltip: 'Add word',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Word input field (inline)
                            if (_showWordInput)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _wordController,
                                        focusNode: _wordFocusNode,
                                        decoration: InputDecoration(
                                          hintText: 'Enter a word',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme.surface,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          isDense: true,
                                        ),
                                        textCapitalization: TextCapitalization.none,
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _addWordFromInput(),
                                        onTap: () {
                                          // Ensure the input field is visible when tapped
                                          Future.delayed(const Duration(milliseconds: 300), () {
                                            if (mounted) {
                                              Scrollable.ensureVisible(
                                                _wordFocusNode.context!,
                                                duration: const Duration(milliseconds: 300),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.check, color: Colors.green),
                                      onPressed: () {
                                        analyticsManager.storeAction('custom_lesson_confirm_word_button_pressed');
                                        _addWordFromInput();
                                      },
                                      tooltip: 'Add word',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.green.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.red),
                                      onPressed: () {
                                        analyticsManager.storeAction('custom_lesson_cancel_word_input_button_pressed');
                                        _hideWordInput();
                                      },
                                      tooltip: 'Cancel',
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.red.withOpacity(0.1),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (_selectedWords.isEmpty && !_showWordInput)
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
                            else if (_selectedWords.isNotEmpty)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedWords.map((word) {
                                  return Chip(
                                    label: Text(
                                      word,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      analyticsManager.storeAction('custom_lesson_word_chip_deleted', word);
                                      _removeWord(word);
                                    },
                                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                                    side: BorderSide(
                                      color: colorScheme.primary.withOpacity(0.2),
                                    ),
                                    labelStyle: TextStyle(
                                      color: colorScheme.primary,
                                    ),
                                    deleteIconColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 14),
                            Text(
                              'You can enter your own in any language.',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flexible spacer
                      const Expanded(
                        flex: 1,
                        child: SizedBox(height: 16),
                      ),

                      // Create Lesson Button
                      Container(
                        width: double.infinity,
                        height: widget.isSmallScreen ? 50 : 56,
                        decoration: BoxDecoration(
                          gradient: _canCreateLesson && !widget.isLoading
                              ? LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.primary.withOpacity(0.8),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [
                                    colorScheme.onSurface.withOpacity(0.12),
                                    colorScheme.onSurface.withOpacity(0.08),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _canCreateLesson && !widget.isLoading
                              ? [
                                  BoxShadow(
                                    color: colorScheme.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (_canCreateLesson && !widget.isLoading)
                                ? () {
                                    _createCustomLesson();
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              alignment: Alignment.center,
                              child: widget.isLoading
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          'Generating Lesson...',
                                          style: TextStyle(
                                            fontSize: widget.isSmallScreen ? 16 : 18,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onPrimary,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          color: _canCreateLesson ? Colors.white : colorScheme.onSurface.withOpacity(0.38),
                                          size: widget.isSmallScreen ? 20 : 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Generate Lesson',
                                          style: TextStyle(
                                            fontSize: widget.isSmallScreen ? 16 : 18,
                                            fontWeight: FontWeight.w600,
                                            color: _canCreateLesson ? Colors.white : colorScheme.onSurface.withOpacity(0.38),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      // Bottom padding to account for keyboard
                      SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
