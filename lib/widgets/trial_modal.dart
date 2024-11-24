import 'package:flutter/material.dart';
import 'package:parakeet/utils/activate_free_trial.dart';

class TrialModal extends StatelessWidget {
  final String userId;

  const TrialModal({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Your Free Trial'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Try Premium free for 1 month!'),
          SizedBox(height: 10),
          Center(child: Text('• No ads')),
          Center(child: Text('• Up to 10 lessons generation per day')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            await activateFreeTrial(context, userId);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Start Free Trial for 30 Days!'),
        ),
      ],
    );
  }
}
