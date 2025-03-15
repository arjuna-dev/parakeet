import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/onboarding_step.dart';

class LanguageLevelStep extends StatelessWidget {
  final String? selectedLevel;
  final List<String> languageLevels;
  final Function(String) onLevelChanged;

  const LanguageLevelStep({
    Key? key,
    required this.selectedLevel,
    required this.languageLevels,
    required this.onLevelChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      icon: Icons.school,
      title: 'What\'s your current level?',
      content: Column(
        children: languageLevels.map((level) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              onTap: () => onLevelChanged(level),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedLevel == level ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                    width: 2,
                  ),
                  color: selectedLevel == level ? Theme.of(context).colorScheme.primaryContainer : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedLevel == level ? Icons.check_circle : Icons.circle_outlined,
                      color: selectedLevel == level ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      level,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: selectedLevel == level ? FontWeight.bold : FontWeight.normal,
                        color: selectedLevel == level ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
