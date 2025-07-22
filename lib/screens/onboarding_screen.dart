import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/progress_indicator.dart';
import 'package:parakeet/widgets/onboarding_screen/welcome_step.dart';
import 'package:parakeet/widgets/onboarding_screen/context_step.dart';
import 'package:parakeet/widgets/onboarding_screen/science_step.dart';
import 'package:parakeet/widgets/onboarding_screen/ready_step.dart';
import 'package:parakeet/screens/onboarding_form_screen.dart';
import '../utils/save_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnalyticsManager analyticsManager;

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
  }

  void _initializeAnalytics() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      analyticsManager = AnalyticsManager(user.uid);
      // Track initial screen view
      analyticsManager.storeAction('onboarding_welcome_screen_viewed');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToFormScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            OnboardingProgressIndicator(
              currentPage: _currentPage,
              totalPages: 4,
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
                children: const [
                  WelcomeStep(),
                  ContextStep(),
                  ScienceStep(),
                  ReadyStep(),
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
                        analyticsManager.storeAction('onboarding_screen_previous_page', _currentPage.toString());
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 80),
                  FilledButton(
                    onPressed: () {
                      analyticsManager.storeAction('onboarding_screen_next_page', _currentPage.toString());
                      if (_currentPage < 3) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _navigateToFormScreen();
                      }
                    },
                    child: Text(_currentPage < 3 ? 'Next' : 'Get Started'),
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
