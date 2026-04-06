import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/services/recent_lesson_topics_service.dart';
import 'package:parakeet/utils/example_scenarios.dart';
import 'package:parakeet/utils/save_analytics.dart';

class GrammarLessonForm extends StatefulWidget {
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final bool isSmallScreen;
  final bool isLoading;
  final ValueChanged<String>? onLessonStarted;

  const GrammarLessonForm({
    super.key,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    this.isSmallScreen = false,
    this.isLoading = false,
    this.onLessonStarted,
  });

  @override
  State<GrammarLessonForm> createState() => _GrammarLessonFormState();
}

class _GrammarLessonFormState extends State<GrammarLessonForm> {
  static const List<String> _scriptFontFallback = [
    'Noto Sans',
    'Noto Sans Arabic',
    'Noto Sans JP',
    'Noto Sans KR',
    'Noto Sans SC',
    'Noto Sans TC',
    'Noto Sans Devanagari',
    'Noto Sans Thai',
    'Noto Sans Hebrew',
    'Arial Unicode MS',
    'PingFang SC',
    'Hiragino Sans',
    'Microsoft YaHei',
    'Malgun Gothic',
    'Segoe UI Symbol',
  ];

  final TextEditingController _topicController = TextEditingController();
  final FocusNode _topicFocusNode = FocusNode();
  bool _isSuggestingRandom = false;
  late AnalyticsManager analyticsManager;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      analyticsManager = AnalyticsManager(user.uid);
    }
    _topicController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _populateRandomTopicAsync());
  }

  @override
  void dispose() {
    _topicController.dispose();
    _topicFocusNode.dispose();
    super.dispose();
  }

  bool get _canCreateLesson => _topicController.text.trim().isNotEmpty;

  bool get _useTopicPicker {
    const supportedNativeLanguages = {
      'English (Australia)',
      'English (UK)',
      'English (US)',
    };
    return supportedNativeLanguages.contains(widget.nativeLanguage);
  }

  String get _levelBucket {
    final normalized = widget.languageLevel.toLowerCase();
    if (normalized.contains('b1') ||
        normalized.contains('b2') ||
        normalized.contains('intermediate')) {
      return 'intermediate';
    }
    if (normalized.contains('c1') ||
        normalized.contains('c2') ||
        normalized.contains('advanced')) {
      return 'advanced';
    }
    return 'beginner';
  }

  List<String> get _levelTopics =>
      grammarLessonTopicsByLevel[_levelBucket] ?? grammarLessonTopics;

  String get _levelLabel {
    switch (_levelBucket) {
      case 'intermediate':
        return 'Best for intermediate learners';
      case 'advanced':
        return 'Best for advanced learners';
      default:
        return 'Best for beginner learners';
    }
  }

  Future<void> _populateRandomTopicAsync() async {
    try {
      final topic = await _pickLocalFallbackTopic();
      if (!mounted) return;
      setState(() {
        _topicController.text = topic;
      });
    } catch (e) {
      debugPrint('Failed to populate grammar topic: $e');
    }
  }

  Future<String> _pickLocalFallbackTopic() async {
    final topicPool = _levelTopics;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      return RecentLessonTopicsService.pickUnusedScenarioKey(
        topicPool,
        uid,
        widget.targetLanguage,
        lessonType: RecentLessonTopicsService.grammarLessonType,
      );
    }
    return topicPool[Random().nextInt(topicPool.length)];
  }

  Future<void> _suggestRandomLesson() async {
    setState(() {
      _isSuggestingRandom = true;
    });

    try {
      final suggestion = await LessonService.suggestGrammarLessonTopic(
        targetLanguage: widget.targetLanguage,
        nativeLanguage: widget.nativeLanguage,
        languageLevel: widget.languageLevel,
      );
      final fallback = await _pickLocalFallbackTopic();
      if (!mounted) return;
      setState(() {
        _topicController.text = suggestion['topic']?.trim().isNotEmpty == true
            ? suggestion['topic']!
            : fallback;
      });
    } catch (e) {
      final fallback = await _pickLocalFallbackTopic();
      if (!mounted) return;
      setState(() {
        _topicController.text = fallback;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSuggestingRandom = false;
        });
      }
    }
  }

  Future<void> _showTopicPicker() async {
    final selectedTopic = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final commonTopics = _levelTopics;
        final extraTopics = grammarLessonTopics
            .where((topic) => !commonTopics.contains(topic))
            .toList();
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Common topics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _levelLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...commonTopics.map((topic) => Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          topic,
                          style: const TextStyle(
                            fontFamilyFallback: _scriptFontFallback,
                          ),
                        ),
                        trailing: _topicController.text.trim() == topic
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(topic),
                      ),
                      Divider(
                        color: colorScheme.outlineVariant.withOpacity(0.35),
                        height: 1,
                      ),
                    ],
                  )),
              if (extraTopics.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'More topics',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ...extraTopics.map((topic) => Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            topic,
                            style: const TextStyle(
                              fontFamilyFallback: _scriptFontFallback,
                            ),
                          ),
                          trailing: _topicController.text.trim() == topic
                              ? Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(topic),
                        ),
                        Divider(
                          color: colorScheme.outlineVariant.withOpacity(0.35),
                          height: 1,
                        ),
                      ],
                    )),
              ],
            ],
          ),
        );
      },
    );

    if (selectedTopic == null || !mounted) return;
    setState(() {
      _topicController.text = selectedTopic;
    });
  }

  void _createLesson() {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a grammar topic for your lesson'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    widget.onLessonStarted?.call(topic);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
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
                      'Grammar Topic',
                      style: TextStyle(
                        fontSize: widget.isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _isSuggestingRandom ? null : _suggestRandomLesson,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: _isSuggestingRandom
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : const Icon(Icons.auto_awesome, size: 14),
                      label: const Text('Random'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 96,
                  child: TextField(
                    controller: _topicController,
                    focusNode: _topicFocusNode,
                    readOnly: true,
                    enableInteractiveSelection: false,
                    showCursor: false,
                    cursorColor: colorScheme.primary,
                    onTap: _useTopicPicker ? _showTopicPicker : null,
                    style: const TextStyle(
                      fontFamilyFallback: _scriptFontFallback,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: _useTopicPicker
                          ? 'Choose a grammar topic'
                          : 'Enter a grammar topic',
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontFamilyFallback: _scriptFontFallback,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      prefixIcon: Icon(
                        Icons.menu_book_rounded,
                        color: colorScheme.primary,
                      ),
                      suffixIcon: _topicController.text.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _topicController.clear,
                                ),
                                if (_useTopicPicker) ...[
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            )
                          : (_useTopicPicker
                              ? Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : null),
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _useTopicPicker
                      ? 'Pick a topic from the list or use Random. Parakeet will adapt the explanations and examples to your current learner level.'
                      : 'Use Random to get a suggested grammar topic. Parakeet will adapt the explanations and examples to your current learner level.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: widget.isSmallScreen ? 50 : 56,
            decoration: BoxDecoration(
              gradient: _canCreateLesson && !widget.isLoading
                  ? LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.4),
                        colorScheme.secondary,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        colorScheme.onSurface.withOpacity(0.12),
                        colorScheme.onSurface.withOpacity(0.08),
                      ],
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: (_canCreateLesson && !widget.isLoading)
                    ? _createLesson
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Center(
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
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.record_voice_over_rounded,
                              color: _canCreateLesson
                                  ? Colors.white
                                  : colorScheme.onSurface.withOpacity(0.38),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Generate Grammar Lesson',
                              style: TextStyle(
                                fontSize: widget.isSmallScreen ? 16 : 18,
                                color: _canCreateLesson
                                    ? Colors.white
                                    : colorScheme.onSurface.withOpacity(0.38),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
