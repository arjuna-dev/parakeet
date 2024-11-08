import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TrialModal extends StatelessWidget {
  final String userId;

  const TrialModal({super.key, required this.userId});

  Future<void> _activateFreeTrial() async {
    final now = DateTime.now();
    final expiryDate = now.add(const Duration(days: 30));

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'premium': true,
      'trialStartDate': now,
      'trialExpiryDate': expiryDate,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start Your Free Trial'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Try Premium free for 1 month!'),
          SizedBox(height: 10),
          Text('• Unlimited lesson creation'),
          Text('• Access to all premium voices'),
          Text('• No ads'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _activateFreeTrial();
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Start Free Trial'),
        ),
      ],
    );
  }
}
