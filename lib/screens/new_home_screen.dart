import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'package:parakeet/services/daily_lesson_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/services/loading_state_service.dart';
import 'package:parakeet/services/audio_player_manager.dart';
import 'package:parakeet/utils/example_scenarios.dart';
import 'package:parakeet/widgets/home_screen/audio_waveform_widget.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _progressData;
  bool _isLoading = true;
  bool _isStartingLesson = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userData = await ProfileService.fetchUserData();
    final progressData = await DailyLessonService.getDailyProgressData();

    setState(() {
      _userData = userData;
      _progressData = progressData;
      _isLoading = false;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final userName = _userData?['name'] ?? 'there';
    final targetLanguage = _userData?['target_language'] ?? 'French';
    final used = _progressData?['used'] ?? 0;
    final limit = _progressData?['limit'] ?? 4;
    final progress = limit > 0 ? used / limit : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AppBarWithDrawer(
        title: 'Home',
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top section with profile greeting
            _buildTopSection(context, userName, colorScheme),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Audio visualization
                    const Center(
                      child: AudioWaveformWidget(),
                    ),

                    const SizedBox(height: 40),

                    // Lesson prompt
                    _buildLessonPrompt(context, targetLanguage, colorScheme),

                    const SizedBox(height: 32),

                    // Action buttons
                    _buildActionButtons(context, colorScheme),

                    const SizedBox(height: 80),
                    // Daily Goal section
                    // _buildDailyGoalSection(
                    //     context, used, limit, progress, colorScheme),

                    // const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(
      BuildContext context, String userName, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),

          // Greeting
          Expanded(
            child: Text(
              '${_getGreeting()}, $userName!',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalSection(
    BuildContext context,
    int used,
    int limit,
    double progress,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goal',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),

        const SizedBox(height: 8),

        // Progress text
        Text(
          '$used/$limit lessons completed',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonPrompt(
      BuildContext context, String targetLanguage, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready for your daily $targetLanguage lesson?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Just 10 minutes to sound more like a local.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Future<void> _startDailyLesson(BuildContext context) async {
    final loadingState = Provider.of<LoadingStateService>(context, listen: false);

    // Check daily lessons remaining first before starting
    var remainingLessons = await LessonService.getCurrentCredits();
    if (remainingLessons <= 0) {
      // Show premium dialog and navigate to store if user wants to upgrade
      await LessonService.showPremiumDialog(context);
      
      // Re-check credits in case user purchased premium
      remainingLessons = await LessonService.getCurrentCredits();
      if (remainingLessons <= 0) {
        // Still no credits, user didn't purchase premium or purchase didn't complete
        return;
      }
    }

    setState(() {
      _isStartingLesson = true;
    });
    loadingState.setGeneratingLesson(true);

    try {
      // Get user language settings
      final settings = await UserService.getUserLanguageSettings();
      final nativeLanguage = settings['nativeLanguage']!;
      final targetLanguage = settings['targetLanguage']!;
      final languageLevel = settings['languageLevel']!;

      // Get random lesson suggestion with fallback to local scenarios
      Map<String, dynamic> suggestion;
    
      final random = Random();
      final scenarios = scenarioKeywords.keys.toList();
      if (scenarios.isEmpty) {
        throw Exception('No scenarios available');
      }
      final randomScenario = scenarios[random.nextInt(scenarios.length)];
      final scenarioWords = scenarioKeywords[randomScenario]!;
      
      suggestion = {
        'topic': randomScenario,
        'words_to_learn': scenarioWords.take(5).toList(),
      };
      

      if (!mounted) return;

      final topic = suggestion['topic'] as String? ?? 'Daily Lesson';
      final wordsList = suggestion['words_to_learn'] as List<dynamic>? ?? [];
      final words = wordsList.map((w) => w.toString()).toList();

      if (words.isEmpty) {
        throw Exception('No words returned from suggestion');
      }

      // Create the lesson - this will trigger the audio player automatically
      await LessonService.createCustomLesson(
        context,
        topic,
        words,
        nativeLanguage,
        targetLanguage,
        languageLevel,
        (bool value) {
          // Update loading state from service
          if (mounted) {
            loadingState.setGeneratingLesson(value);
          }
        },
      );

      // Ensure audio player is visible - createCustomLesson calls manager.playLesson() internally
      // The persistent audio player should appear automatically since we're on /favorite route
      if (mounted) {
        // Small delay to ensure audio player manager has time to update
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      // Show error message
      print('Error starting daily lesson: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start lesson: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isStartingLesson = false;
        });
        loadingState.setGeneratingLesson(false);
      }
    }
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        // Start Daily Lesson button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isStartingLesson ? null : () => _startDailyLesson(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isStartingLesson
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Start Daily Lesson',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        // Customize Topic button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/custom_lesson');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Customize Topic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
