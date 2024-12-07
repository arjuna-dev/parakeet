import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

Future<bool> activateFreeTrial(BuildContext context, String userId) async {
  final bool available = await InAppPurchase.instance.isAvailable();
  late PurchaseParam purchaseParam;
  if (!available) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store is not available')),
      );
    }
    return false;
  }

  // Query for the trial product
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails({'1m'}.toSet());

  if (response.notFoundIDs.isNotEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trial subscription not found')),
      );
    }
    return false;
  }

  final ProductDetails product = response.productDetails.first;

  if (Platform.isAndroid) {
    purchaseParam = GooglePlayPurchaseParam(productDetails: product, changeSubscriptionParam: null);
  } else {
    purchaseParam = PurchaseParam(productDetails: product);
  }

  try {
    // Create a Completer to wait for the purchase result
    final completer = Completer<bool>();

    // Listen to the purchase stream
    late StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = InAppPurchase.instance.purchaseStream.listen(
      (List<PurchaseDetails> purchases) async {
        for (final purchase in purchases) {
          if (purchase.status == PurchaseStatus.purchased) {
            // Purchase was successful
            await FirebaseFirestore.instance.collection('users').doc(userId).update({
              'hasUsedTrial': true,
            });

            // Complete the purchase
            await InAppPurchase.instance.completePurchase(purchase);

            // Complete with success
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } else if (purchase.status == PurchaseStatus.error) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Purchase failed: ${purchase.error}')),
              );
            }
            // Complete with failure
            if (!completer.isCompleted) {
              completer.complete(false);
            }
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    // Start the purchase flow
    await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);

    // Wait for the purchase to complete (with timeout)
    final success = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        subscription.cancel();
        return false;
      },
    );

    // Clean up subscription
    subscription.cancel();
    return success;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start trial: $e')),
      );
    }
    return false;
  }
}
