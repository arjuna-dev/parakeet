import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/onboarding_step.dart';

class NicknameStep extends StatelessWidget {
  final Function(String) onNicknameChanged;

  const NicknameStep({
    Key? key,
    required this.onNicknameChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OnboardingStep(
      icon: Icons.person,
      title: 'What would you like to be called?',
      content: TextField(
        onChanged: onNicknameChanged,
        decoration: InputDecoration(
          hintText: 'Enter your nickname',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}
