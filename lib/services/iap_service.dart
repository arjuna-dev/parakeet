import 'package:cloud_functions/cloud_functions.dart';
import 'package:parakeet/services/firebase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  String uid;
  IAPService(this.uid);

  void listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          _handleSuccessfulPurchase(purchaseDetails);
        }
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        print(purchaseDetails.error!);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    });
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    if (purchaseDetails.productID == '1m' || purchaseDetails.productID == '1year') {
      FirebaseService().setAccountType(uid: uid, type: 'premium');
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    final verifier = FirebaseFunctions.instanceFor(region: "europe-west1").httpsCallable('verifyPurchase');
    final results = await verifier({
      'source': purchaseDetails.verificationData.source,
      'verificationData': purchaseDetails.verificationData.serverVerificationData,
      'productId': purchaseDetails.productID,
    });
    return results.data as bool;
  }
}
