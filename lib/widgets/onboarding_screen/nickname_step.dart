import 'package:flutter/material.dart';
import 'package:parakeet/widgets/onboarding_screen/onboarding_step.dart';

class NicknameStep extends StatefulWidget {
  final String? initialNickname;
  final bool isAppleSignIn;
  final String? appleUserName;
  final Function(String) onNicknameChanged;

  const NicknameStep({
    Key? key,
    this.initialNickname,
    this.isAppleSignIn = false,
    this.appleUserName,
    required this.onNicknameChanged,
  }) : super(key: key);

  @override
  State<NicknameStep> createState() => _NicknameStepState();
}

class _NicknameStepState extends State<NicknameStep> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNickname ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String title = 'What would you like to be called?';
    String hintText = 'Enter your nickname';

    // Customize for Apple Sign In users
    if (widget.isAppleSignIn && widget.appleUserName != null && widget.appleUserName!.isNotEmpty) {
      title = 'Confirm your preferred name';
      hintText = 'Your first name from Apple ID';
    }

    // Use a custom layout instead of OnboardingStep to handle overflow better
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60), // Top spacing
          const Icon(Icons.person, size: 64),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (widget.isAppleSignIn && widget.appleUserName != null && widget.appleUserName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'We\'ve pre-filled this with your first name from Apple ID. You can change it if you prefer something else.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          TextField(
            controller: _controller,
            onChanged: widget.onNicknameChanged,
            decoration: InputDecoration(
              hintText: hintText,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(height: 60), // Bottom spacing
        ],
      ),
    );
  }
}
