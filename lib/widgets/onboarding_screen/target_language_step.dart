import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/onboarding_step.dart';

class TargetLanguageStep extends StatelessWidget {
  final String? selectedLanguage;
  final List<String> supportedLanguages;
  final Function(String?) onLanguageChanged;

  const TargetLanguageStep({
    Key? key,
    required this.selectedLanguage,
    required this.supportedLanguages,
    required this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      icon: Icons.translate,
      title: 'What language do you want to learn?',
      content: Theme(
        data: Theme.of(context).copyWith(
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
              backgroundColor: WidgetStateProperty.all(
                const Color(0xFF0F3D37), // Explicit dark green color
              ),
            ),
          ),
        ),
        child: DropdownButtonFormField<String>(
          initialValue: selectedLanguage,
          dropdownColor: const Color(0xFF0F3D37), // Explicit dark green color
          iconEnabledColor: Theme.of(context).colorScheme.onSurface,
          iconDisabledColor: Theme.of(context).colorScheme.onSurfaceVariant,
          decoration: InputDecoration(
          fillColor: const Color(0xFF0F3D37), // Explicit dark green color
          filled: true,
          hoverColor: const Color(0xFF0F3D37), // Explicit dark green color
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        items: supportedLanguages.map((String language) {
          return DropdownMenuItem<String>(
            value: language,
            child: Text(
              language,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
          onChanged: onLanguageChanged,
        ),
      ),
    );
  }
}
