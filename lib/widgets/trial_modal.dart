import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class TrialModal extends StatelessWidget {
  final String userId;

  const TrialModal({super.key, required this.userId});

  Future<void> _activateFreeTrial(BuildContext context) async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Store is not available')),
        );
      }
      return;
    }

    // Query for the trial product
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails({'1m'}.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trial subscription not found')),
        );
      }
      return;
    }

    final ProductDetails product = response.productDetails.first;

    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );

    try {
      final bool success = await InAppPurchase.instance
          .buyNonConsumable(purchaseParam: purchaseParam);

      if (success) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'premium': true,
          'trialOffered': true,
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trial: $e')),
        );
      }
    }
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
            await _activateFreeTrial(context);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('Start Free Trial for 30 Days'),
        ),
      ],
    );
  }
}
