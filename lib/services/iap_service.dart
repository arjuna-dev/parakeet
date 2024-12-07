import 'package:cloud_functions/cloud_functions.dart';
import 'package:parakeet/services/firebase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class IAPService {
  String uid;
  IAPService(this.uid);

  void listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
      print("purchaseDetails.status ${purchaseDetails.status}");
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        bool valid = await _verifyPurchase(purchaseDetails);
        if (valid) {
          print("Purchase verified");
          _handleSuccessfulPurchase(purchaseDetails);
        }
      }

      if (purchaseDetails.status == PurchaseStatus.error) {
        print(purchaseDetails.error!);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
        print("Purchase marked complete");
      }
    });
  }

  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    print('handling!!!');
    if (purchaseDetails.productID == '1m' || purchaseDetails.productID == '1year') {
      FirebaseService().setAccountType(uid: uid, type: 'premium');
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    print("Verifying Purchase");
    final verifier = FirebaseFunctions.instanceFor(region: "europe-west1").httpsCallable('verifyPurchase');
    final results = await verifier({
      'source': purchaseDetails.verificationData.source,
      'verificationData': purchaseDetails.verificationData.serverVerificationData,
      'productId': purchaseDetails.productID,
    });
    print("Called verify purchase with following result $results");
    return results.data as bool;
  }
}
