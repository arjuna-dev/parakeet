import 'package:flutter/material.dart';

class OnboardingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget content;

  const OnboardingStep({
    Key? key,
    required this.icon,
    required this.title,
    required this.content,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: content,
        ),
      ],
    );
  }
}
