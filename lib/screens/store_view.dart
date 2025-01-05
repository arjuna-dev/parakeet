import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

const List<String> _productIds = <String>[
  '1m',
  '1year',
];

class _StoreViewState extends State<StoreView> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isAvailable = false;
  String? _notice;
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _hasPremium = false;
  bool _hasUsedTrial = false;

  @override
  void initState() {
    super.initState();
    checkPremiumStatus();
  }

  Future<void> checkPremiumStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _loading = false;
          _notice = "Please sign in to access the store";
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

      final isPremium = userDoc.data()?['premium'] ?? false;
      final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

      setState(() {
        _hasPremium = isPremium;
        _hasUsedTrial = hasUsedTrial;
      });

      if (!_hasPremium) {
        await initStoreInfo();
      } else {
        setState(() {
          _loading = false;
          _notice = "You already have premium access!";
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _notice = "No store access";
      });
    }
  }

  Future<void> initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    setState(() {
      _isAvailable = isAvailable;
    });

    if (!_isAvailable) {
      setState(() {
        _loading = false;
        _notice = "There are no upgrades at this time";
      });
      return;
    }

    // get IAP.
    ProductDetailsResponse productDetailsResponse = await _inAppPurchase.queryProductDetails(_productIds.toSet());

    setState(() {
      _loading = false;
      _products = productDetailsResponse.productDetails;
    });

    if (productDetailsResponse.error != null) {
      setState(() {
        _notice = "There was a problem connecting to the store";
      });
    } else if (productDetailsResponse.productDetails.isEmpty) {
      setState(() {
        _notice = "There are no upgrades at this time";
      });
    }
  }

  bool _hasIntroductoryOffer(ProductDetails product) {
    if (Platform.isAndroid) {
      final GooglePlayProductDetails googleProduct = product as GooglePlayProductDetails;
      final offerDetails = googleProduct.productDetails.subscriptionOfferDetails;

      // Check if there are any offers and the first phase is free
      return offerDetails != null && offerDetails.isNotEmpty && offerDetails.first.pricingPhases.first.priceAmountMicros == 0;
    } else if (Platform.isIOS) {
      final AppStoreProductDetails iOSProduct = product as AppStoreProductDetails;
      return iOSProduct.skProduct.introductoryPrice != null;
    }
    return false;
  }

  Future<void> _makePurchase(ProductDetails productDetails) async {
    late PurchaseParam purchaseParam;

    if (Platform.isAndroid) {
      purchaseParam = GooglePlayPurchaseParam(productDetails: productDetails, changeSubscriptionParam: null);
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    if (productDetails.id == "1m" || productDetails.id == "1year") {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      if (_hasIntroductoryOffer(productDetails) && !_hasUsedTrial) {
        // Update the user's trial status in Firestore
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('users').doc(userId).update({'hasUsedTrial': true});
        }
      }
    }
  }

  void _launchURL(Uri url) async {
    await canLaunchUrl(url) ? await launchUrl(url) : throw 'Could not launch $url';
  }

  List<ProductDetails> _getUniqueProducts() {
    final uniqueProducts = <ProductDetails>[];
    for (var product in _products) {
      if (!uniqueProducts.any((p) => p.id == product.id)) {
        uniqueProducts.add(product);
      }
    }
    return uniqueProducts;
  }

  Widget _buildSubscriptionCard(ProductDetails productDetails) {
    bool hasIntro = _hasIntroductoryOffer(productDetails);
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 4 : 8,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 12,
            ),
            leading: Container(
              width: isSmallScreen ? 40 : 48,
              height: isSmallScreen ? 40 : 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                productDetails.id == "1year" ? Icons.star : Icons.star_half,
                color: colorScheme.primary,
                size: isSmallScreen ? 20 : 24,
              ),
            ),
            title: Text(
              productDetails.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 15 : 16,
              ),
            ),
            subtitle: Text(
              productDetails.description,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 12 : 13,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasIntro && !_hasUsedTrial
                        ? '30-day free trial'
                        : productDetails.id == "1m"
                            ? 'Monthly subscription'
                            : 'Annual subscription',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 24,
                      vertical: isSmallScreen ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _makePurchase(productDetails),
                  child: Text(
                    hasIntro && !_hasUsedTrial ? 'Start Free Trial' : productDetails.price,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          children: [
            Container(
              width: isSmallScreen ? 48 : 56,
              height: isSmallScreen ? 48 : 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _hasPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                size: isSmallScreen ? 28 : 32,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              _hasPremium ? 'Premium Member' : 'Upgrade to Premium',
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              _hasPremium ? 'Enjoy all premium features' : 'Get unlimited access to all features',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Store",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              if (_notice != null)
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: Text(
                    _notice!,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                  ),
                ),
              if (_loading)
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              if (!_hasPremium && _products.isNotEmpty) ..._getUniqueProducts().map(_buildSubscriptionCard),
              if (!_hasPremium)
                Card(
                  elevation: 2,
                  margin: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isSmallScreen ? 4 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 8 : 12,
                    ),
                    leading: Container(
                      width: isSmallScreen ? 40 : 48,
                      height: isSmallScreen ? 40 : 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restore,
                        color: colorScheme.primary,
                        size: isSmallScreen ? 20 : 24,
                      ),
                    ),
                    title: Text(
                      'Restore Purchases',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 15 : 16,
                      ),
                    ),
                    subtitle: Text(
                      'Recover your previous purchases',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                    onTap: () => _inAppPurchase.restorePurchases(),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _launchURL(Uri(
                        scheme: "https",
                        host: "gregarious-giant-4a5.notion.site",
                        path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26",
                      )),
                      child: Text(
                        'Terms and Conditions',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ),
                    Text(
                      ' • ',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isSmallScreen ? 12 : 13,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _launchURL(Uri.parse("https://parakeet.world/privacypolicy")),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: isSmallScreen ? 12 : 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
            ],
          ),
        ),
      ),
    );
  }
}
