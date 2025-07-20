import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/home_screen/custom_lesson_form.dart';
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
    // This method can be empty since we're not managing lesson lists anymore
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

      // After successful lesson creation, navigate back to the lessons list
      if (mounted) {
        Navigator.pop(context);
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
          appBar: AppBar(
            title: const Text('Generate Custom Lesson'),
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
            ),
          ),
          body: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Header section
                        Center(
                          child: Container(
                            width: double.infinity,
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: colorScheme.primary,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Text(
                                    'Create personalized lessons with your own topics and words',
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Custom lesson form
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: CustomLessonForm(
                              nativeLanguage: nativeLanguage,
                              targetLanguage: targetLanguage,
                              languageLevel: languageLevel,
                              isSmallScreen: isSmallScreen,
                              onLessonStarted: (topic, words) {
                                _handleLessonCreation(topic, words); // Start lesson creation
                              },
                              onLessonCreated: () {
                                // Navigation handled in _handleLessonCreation
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

              // Loading overlay to block interactions
              if (isGeneratingLesson)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Generating your custom lesson...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
