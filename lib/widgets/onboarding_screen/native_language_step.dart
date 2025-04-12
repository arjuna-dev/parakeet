import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/onboarding_step.dart';

class NativeLanguageStep extends StatelessWidget {
  final String? selectedLanguage;
  final List<String> supportedLanguages;
  final Function(String?) onLanguageChanged;

  const NativeLanguageStep({
    Key? key,
    required this.selectedLanguage,
    required this.supportedLanguages,
    required this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      icon: Icons.language,
      title: 'What is your native language?',
      content: DropdownButtonFormField<String>(
        value: selectedLanguage,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        items: supportedLanguages.map((String language) {
          return DropdownMenuItem<String>(
            value: language,
            child: Text(language),
          );
        }).toList(),
        onChanged: onLanguageChanged,
      ),
    );
  }
}
