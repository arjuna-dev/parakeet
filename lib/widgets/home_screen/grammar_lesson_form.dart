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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      return RecentLessonTopicsService.pickUnusedScenarioKey(
        grammarLessonTopics,
        uid,
        widget.targetLanguage,
        lessonType: RecentLessonTopicsService.grammarLessonType,
      );
    }
    return grammarLessonTopics[Random().nextInt(grammarLessonTopics.length)];
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Using an offline grammar topic suggestion.'),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSuggestingRandom = false;
        });
      }
    }
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
                          : const Icon(Icons.auto_awesome, size: 16),
                      label: const Text('Generate Random'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _topicController,
                  focusNode: _topicFocusNode,
                  cursorColor: colorScheme.primary,
                  decoration: InputDecoration(
                    hintText:
                        'Try “past tense”, “asking polite questions”, “using articles”',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    suffixIcon: _topicController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _topicController.clear,
                          )
                        : null,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 10),
                Text(
                  'Parakeet will adapt the explanations and examples to your current learner level.',
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
