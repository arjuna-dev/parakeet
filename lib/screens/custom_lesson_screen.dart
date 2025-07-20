import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/home_screen/custom_lesson_form.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/services/lesson_credit_service.dart';
import 'package:parakeet/services/loading_state_service.dart';

class CustomLessonScreen extends StatefulWidget {
  const CustomLessonScreen({Key? key}) : super(key: key);

  @override
  State<CustomLessonScreen> createState() => _CustomLessonScreenState();
}

class _CustomLessonScreenState extends State<CustomLessonScreen> {
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Screen is ready
  }

  void _loadUserPreferences() async {
    try {
      final settings = await UserService.getUserLanguageSettings();
      setState(() {
        nativeLanguage = settings['nativeLanguage']!;
        targetLanguage = settings['targetLanguage']!;
        languageLevel = settings['languageLevel']!;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLessonCreation(String topic, List<String> words) async {
    final loadingState = Provider.of<LoadingStateService>(context, listen: false);

    // Check credits first before setting loading state (but don't deduct yet - server will handle deduction)
    final currentCredits = await LessonCreditService.getCurrentCredits();
    if (currentCredits <= 0) {
      // Show premium dialog and navigate to store if user wants to upgrade
      final shouldEnablePremium = await LessonService.showPremiumDialog(context);
      if (!shouldEnablePremium) {
        return;
      }
    }

    // Only set loading state if we have credits
    loadingState.setGeneratingLesson(true);

    try {
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

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson created successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lesson: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        loadingState.setGeneratingLesson(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<LoadingStateService>(
      builder: (context, loadingState, child) {
        final isGeneratingLesson = loadingState.isGeneratingLesson;
        return Scaffold(
          appBar: const AppBarWithDrawer(
            title: 'Custom Lessons',
          ),
          body: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Header with title and icon
                        Container(
                          width: double.infinity,
                          color: colorScheme.surface,
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            10,
                            20,
                            10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Create personalized lessons with your own topics and words',
                                  style: TextStyle(
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Custom lesson form
                        Expanded(
                          child: CustomLessonForm(
                            nativeLanguage: nativeLanguage,
                            targetLanguage: targetLanguage,
                            languageLevel: languageLevel,
                            isSmallScreen: isSmallScreen,
                            onLessonStarted: (topic, words) {
                              _handleLessonCreation(topic, words); // Start lesson creation
                            },
                            onLessonCreated: () {
                              // Lesson created successfully
                            },
                          ),
                        ),
                      ],
                    ),

              // Loading overlay to block interactions
              if (isGeneratingLesson)
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
            ],
          ),
        );
      },
    );
  }
}
