import 'package:flutter/material.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/widgets/library_screen/lesson_item.dart';

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
  final TextEditingController _wordController = TextEditingController();
  final FocusNode _topicFocusNode = FocusNode();
  final FocusNode _wordFocusNode = FocusNode();
  final List<String> _selectedWords = [];
  final HomeScreenModel _model = HomeScreenModel();
  Map<String, bool> _localFavorites = {};
  List<DocumentSnapshot> _customLessons = [];
  bool _isCreatingCustomLesson = false;
  bool _isSuggestingRandom = false;
  bool _isLoadingLessons = true;
  bool _showWordInput = false;

  @override
  void initState() {
    super.initState();
    _loadCustomLessons();
    // Listen to topic changes to update button state
    _topicController.addListener(_updateButtonState);
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
    setState(() {
      // This will trigger a rebuild and update the button state
    });
  }

  bool get _canCreateLesson {
    return _topicController.text.trim().isNotEmpty && _selectedWords.isNotEmpty && !_isCreatingCustomLesson;
  }

  Future<void> _loadCustomLessons() async {
    setState(() => _isLoadingLessons = true);
    try {
      await _model.loadAudioFiles();

      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

      // Filter for custom lessons (where category is null, empty, or "Custom Lesson")
      final filteredData = snapshot.docs.where((doc) {
        final data = doc.data();
        return !data.containsKey('category') || data['category'] == null || data['category'].toString().isEmpty || data['category'] == 'Custom Lesson';
      });

      // Initialize _localFavorites map with current favorite state
      Map<String, bool> initialFavorites = {};
      for (var doc in filteredData) {
        String parentId = doc.reference.parent.parent!.id;
        String docId = doc.reference.id;
        String key = '$parentId-$docId';

        initialFavorites[key] = _model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId);
      }

      setState(() {
        _customLessons = filteredData.toList();
        // Sort by timestamp (newest first)
        _customLessons.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));
        _localFavorites = initialFavorites;
        _isLoadingLessons = false;
      });
    } catch (e) {
      print('Error loading custom lessons: $e');
      setState(() => _isLoadingLessons = false);
    }
  }

  void _addWord(String word) {
    if (word.trim().isEmpty) return;

    final normalizedWord = word.trim().toLowerCase();
    setState(() {
      if (_selectedWords.length < LessonConstants.maxWordsAllowed && !_selectedWords.contains(normalizedWord)) {
        _selectedWords.add(normalizedWord);
      }
    });
  }

  void _removeWord(String word) {
    setState(() {
      _selectedWords.remove(word);
    });
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
    setState(() {
      _showWordInput = false;
    });
    _wordController.clear();
    _wordFocusNode.unfocus();
  }

  void _dismissKeyboard() {
    _topicFocusNode.unfocus();
    _wordFocusNode.unfocus();
    FocusScope.of(context).unfocus();
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
      _selectedWords.clear();
      // Reload lessons to show the newly created one
      _loadCustomLessons();
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

  Future<void> _refreshCustomLessons() async {
    setState(() {
      _loadCustomLessons();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        body: ListView(
          children: [
            // Form Section
            Padding(
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
                                      _topicController.clear();
                                      _updateButtonState();
                                    },
                                  )
                                : null,
                          ),
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _dismissKeyboard(),
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
                                        setState(() {
                                          _showWordInput = true;
                                        });
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          _wordFocusNode.requestFocus();
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
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: _addWordFromInput,
                                  tooltip: 'Add word',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withOpacity(0.1),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red),
                                  onPressed: _hideWordInput,
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
                                    fontSize: widget.isSmallScreen ? 12 : 14,
                                  ),
                                ),
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

                  // Create Lesson Button (moved below form)
                  FilledButton(
                    onPressed: _canCreateLesson ? _createCustomLesson : null,
                    style: FilledButton.styleFrom(
                      minimumSize: Size(double.infinity, widget.isSmallScreen ? 40 : 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isCreatingCustomLesson
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Creating...'),
                            ],
                          )
                        : Text(
                            'Create Custom Lesson',
                            style: TextStyle(
                              fontSize: widget.isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Divider between form and existing lessons
            const SizedBox(height: 8),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 8),

            // Existing Custom Lessons Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Custom Lessons',
                    style: TextStyle(
                      fontSize: widget.isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Loading state or lessons list
                  _isLoadingLessons
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _customLessons.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  'No custom lessons yet.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Column(
                              children: _customLessons
                                  .map((doc) => LessonItem(
                                        document: doc,
                                        category: 'Custom Lesson',
                                        isSmallScreen: widget.isSmallScreen,
                                        model: _model,
                                        localFavorites: _localFavorites,
                                        updateFavorites: (favorites) {
                                          setState(() => _localFavorites = favorites);
                                        },
                                        onDeleteComplete: () {
                                          _refreshCustomLessons();
                                        },
                                      ))
                                  .toList(),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
