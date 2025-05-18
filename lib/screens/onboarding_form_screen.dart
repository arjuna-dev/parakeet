import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/services/onboarding_service.dart';
import 'package:parakeet/widgets/onboarding_screen/progress_indicator.dart';
import 'package:parakeet/widgets/onboarding_screen/native_language_step.dart';
import 'package:parakeet/widgets/onboarding_screen/nickname_step.dart';
import 'package:parakeet/widgets/onboarding_screen/target_language_step.dart';
import 'package:parakeet/widgets/onboarding_screen/language_level_step.dart';
import 'package:parakeet/widgets/onboarding_screen/notifications_step.dart';
import '../utils/native_language_list.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter/foundation.dart';

class OnboardingFormScreen extends StatefulWidget {
  const OnboardingFormScreen({super.key});

  @override
  State<OnboardingFormScreen> createState() => _OnboardingFormScreenState();
}

class _OnboardingFormScreenState extends State<OnboardingFormScreen> {
  final PageController _pageController = PageController();
  final player = AudioPlayer();
  int _currentPage = 0;
  String? _selectedNativeLanguage = 'English (US)';
  String? _nickname;
  String? _selectedTargetLanguage = 'German';
  String? _selectedLanguageLevel = 'Absolute beginner (A1)';
  final List<String> _languageLevels = ['Absolute beginner (A1)', 'Beginner (A2-B1)', 'Intermediate (B2-C1)', 'Advanced (C2)'];
  final List<String> _supportedLanguages = supportedLanguages;
  bool _isLoading = false;
  final int totalPages = kIsWeb ? 4 : 5;
  bool? _notificationsEnabled;

  @override
  void dispose() {
    _pageController.dispose();
    player.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    setState(() {
      _isLoading = loading;
    });
  }

  Future<void> _saveUserData() async {
    final success = await OnboardingService.saveUserData(
      nativeLanguage: _selectedNativeLanguage,
      nickname: _nickname,
      targetLanguage: _selectedTargetLanguage,
      languageLevel: _selectedLanguageLevel,
      setLoading: _setLoading,
      context: context,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/create_lesson');
    }
  }

  bool _canProceed() {
    return OnboardingService.canProceed(
      _currentPage,
      _selectedNativeLanguage,
      _nickname,
      _selectedTargetLanguage,
      _selectedLanguageLevel,
      _notificationsEnabled,
    );
  }

  void _goToNextPage() {
    FocusScope.of(context).unfocus();

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 24),
                OnboardingProgressIndicator(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      NativeLanguageStep(
                        selectedLanguage: _selectedNativeLanguage,
                        supportedLanguages: _supportedLanguages,
                        onLanguageChanged: (value) {
                          setState(() {
                            _selectedNativeLanguage = value;
                          });
                        },
                      ),
                      NicknameStep(
                        onNicknameChanged: (value) {
                          setState(() {
                            _nickname = value;
                          });
                        },
                      ),
                      TargetLanguageStep(
                        selectedLanguage: _selectedTargetLanguage,
                        supportedLanguages: _supportedLanguages,
                        onLanguageChanged: (value) {
                          setState(() {
                            _selectedTargetLanguage = value;
                          });
                        },
                      ),
                      LanguageLevelStep(
                        selectedLevel: _selectedLanguageLevel,
                        languageLevels: _languageLevels,
                        onLevelChanged: (value) {
                          setState(() {
                            _selectedLanguageLevel = value;
                          });
                        },
                      ),
                      if (!kIsWeb)
                        NotificationsPermissionsStep(
                          onNotificationsEnabledChanged: (value) {
                            setState(() {
                              _notificationsEnabled = value;
                            });
                          },
                          notificationsEnabled: _notificationsEnabled,
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        TextButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 80), // Empty space instead of Back button
                      FilledButton(
                        onPressed: _canProceed() ? _goToNextPage : null,
                        child: Text(_currentPage < 3 ? 'Next' : 'Get Started'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );

    // Wrap the content with the ResponsiveScreenWrapper
    if (ResponsiveBreakpoints.of(context).largerThan(MOBILE)) {
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
        color: colorScheme.surfaceBright,
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 350, // Mobile-like width for desktop views
              height: 700,
              child: content,
            ),
          ),
        ),
      );
    } else {
      return content;
    }
  }
}
