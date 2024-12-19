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
      print(_products);
    });

    if (productDetailsResponse.error != null) {
      setState(() {
        _notice = "There was a problem connecting to the store";
      });
    } else if (productDetailsResponse.productDetails.isEmpty) {
      print("No products founds");
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
    print('Attempting purchase of ${productDetails.id}');
    print('Product status: ${productDetails.price}');
    if (Platform.isAndroid) {
      final googleProduct = productDetails as GooglePlayProductDetails;
      print('Subscription offer details: ${googleProduct.productDetails.subscriptionOfferDetails?.first.pricingPhases.first.priceAmountMicros}');
    }
    print(_hasIntroductoryOffer(productDetails));
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

  Widget _getIAPIcon(productId) {
    if (productId == "1m" || productId == "1year") {
      return const Icon(Icons.subscriptions_rounded, size: 25);
    } else {
      return const Icon(Icons.post_add_outlined, size: 50);
    }
  }

  Widget _buyText(ProductDetails productDetails) {
    bool hasIntro = _hasIntroductoryOffer(productDetails);

    if (hasIntro && !_hasUsedTrial) {
      return const Text("Free trial for 30 days");
    }

    if (productDetails.id == "1m") {
      if (productDetails.price == "Free") {
        return const Text("Free for 30 days");
      }
      return Text("${productDetails.price} / month");
    } else if (productDetails.id == "1year") {
      if (productDetails.price == "Free") {
        return const Text("Free for 30 days");
      }
      return Text("${productDetails.price} / year");
    } else {
      return Text("Buy for ${productDetails.price}");
    }
  }

  Widget _buildRestoreButton() {
    if (_loading) {
      return Container();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => _inAppPurchase.restorePurchases(),
          child: const Text('Restore Purchases'),
        )
      ],
    );
  }

  Widget _buildFooterButtons() {
    if (_loading) {
      return Container();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26")),
            child: const Text(
              'Terms and Conditions',
              style: TextStyle(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          const Text(' • '), // Separator dot
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _launchURL(Uri.parse("https://parakeet.world/privacypolicy")),
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                productDetails.id == "1year" ? Icons.star : Icons.star_half,
                color: colorScheme.primary,
              ),
            ),
            title: Text(
              productDetails.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              productDetails.description,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () => _makePurchase(productDetails),
                  child: Text(
                    hasIntro && !_hasUsedTrial ? 'Start Free Trial' : productDetails.price,
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
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              _hasPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _hasPremium ? 'Premium Member' : 'Upgrade to Premium',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasPremium ? 'Enjoy all premium features' : 'Get unlimited access to all features',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_notice!),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_hasPremium && _products.isNotEmpty) ..._getUniqueProducts().map(_buildSubscriptionCard),
              if (!_hasPremium)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore Purchases'),
                    onPressed: () => _inAppPurchase.restorePurchases(),
                  ),
                ),
              _buildFooterButtons(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
