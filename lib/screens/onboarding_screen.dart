import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../utils/native_language_list.dart';
import '../utils/greetings_list_all_languages.dart';
import '../services/cloud_function_service.dart';
import 'dart:math';
import 'dart:async';
import 'package:just_audio/just_audio.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Save user data
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'native_language': _selectedNativeLanguage,
          'nickname': _nickname,
          'target_language': _selectedTargetLanguage,
          'language_level': _selectedLanguageLevel,
          'onboarding_completed': true,
        });

        // Generate nickname greeting in native language
        if (_nickname != null && _nickname!.isNotEmpty) {
          final selectedGreetings = greetingsList[_selectedNativeLanguage]!;
          final usedGreetingIndex = Random().nextInt(selectedGreetings.length);
          final randomGreeting = selectedGreetings[usedGreetingIndex];
          final userIdN = "${user.uid}_${_selectedNativeLanguage}_${usedGreetingIndex + 1}";

          // Generate initial greeting
          await CloudFunctionService.generateNicknameAudio("$randomGreeting $_nickname!", user.uid, userIdN, _selectedNativeLanguage!);
          await _fetchAndPlayAudio(userIdN);

          // Generate remaining greetings in background
          unawaited(_generateRemainingGreetings(user.uid, _nickname!, _selectedNativeLanguage!, usedGreetingIndex));
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/create_lesson');
        }
      } catch (e) {
        print('Error saving user data or generating nickname: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error saving data. Please try again.'),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchAndPlayAudio(String useridN) async {
    bool audioFetched = false;

    while (!audioFetched) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await urlExists(
          'https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp=$timestamp',
        );

        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        await player.setUrl('https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp2=$timestamp2');
        audioFetched = true;
        player.play();
      } catch (e) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _generateRemainingGreetings(String userId, String nickname, String language, int usedIndex) async {
    try {
      final selectedGreetings = greetingsList[language]!;

      // Generate remaining greetings for selected language, skipping the used one
      for (var i = 0; i < selectedGreetings.length; i++) {
        if (i == usedIndex) continue; // Skip the greeting we already generated
        final greeting = selectedGreetings[i];
        final userIdN = "${userId}_${language}_${i + 1}";
        unawaited(CloudFunctionService.generateNicknameAudio("$greeting $nickname!", userId, userIdN, language));
      }
    } catch (e) {
      print("Error generating remaining greetings: $e");
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildNativeLanguageStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.language, size: 64),
        const SizedBox(height: 24),
        Text(
          'What is your native language?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DropdownButtonFormField<String>(
            value: _selectedNativeLanguage,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            items: _supportedLanguages.map((String language) {
              return DropdownMenuItem<String>(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedNativeLanguage = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.person, size: 64),
        const SizedBox(height: 24),
        Text(
          'What would you like to be called?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _nickname = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Enter your nickname',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetLanguageStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.translate, size: 64),
        const SizedBox(height: 24),
        Text(
          'What language do you want to learn?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: DropdownButtonFormField<String>(
            value: _selectedTargetLanguage,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            items: _supportedLanguages.map((String language) {
              return DropdownMenuItem<String>(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedTargetLanguage = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageLevelStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.school, size: 64),
        const SizedBox(height: 24),
        Text(
          'What\'s your current level?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: _languageLevels.map((level) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedLanguageLevel = level;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedLanguageLevel == level ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                        width: 2,
                      ),
                      color: _selectedLanguageLevel == level ? Theme.of(context).colorScheme.primaryContainer : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedLanguageLevel == level ? Icons.check_circle : Icons.circle_outlined,
                          color: _selectedLanguageLevel == level ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 16),
                        Text(
                          level,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _selectedLanguageLevel == level ? FontWeight.bold : FontWeight.normal,
                            color: _selectedLanguageLevel == level ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0:
        return _selectedNativeLanguage != null;
      case 1:
        return _nickname != null && _nickname!.isNotEmpty;
      case 2:
        return _selectedTargetLanguage != null;
      case 3:
        return _selectedLanguageLevel != null;
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 24),
                _buildProgressIndicator(),
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
                      _buildNativeLanguageStep(),
                      _buildNicknameStep(),
                      _buildTargetLanguageStep(),
                      _buildLanguageLevelStep(),
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
                        const SizedBox(width: 80),
                      FilledButton(
                        onPressed: _canProceed()
                            ? () {
                                if (_currentPage < 3) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                } else {
                                  _saveUserData();
                                }
                              }
                            : null,
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
  }
}
