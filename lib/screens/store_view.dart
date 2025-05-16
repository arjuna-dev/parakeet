import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

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

  String? _getDiscountedPrice(ProductDetails product) {
    if (Platform.isAndroid) {
      final GooglePlayProductDetails googleProduct = product as GooglePlayProductDetails;
      print("googleProduct: ${googleProduct.price}");

      final offerDetails = googleProduct.productDetails.subscriptionOfferDetails;

      if (offerDetails != null && offerDetails.isNotEmpty) {
        print("offerDetails: ${offerDetails.first.pricingPhases.length}");
        final phases = offerDetails.first.pricingPhases;
        final discountedFormattedPrice = phases.first.formattedPrice;
        return discountedFormattedPrice;
      }
    } else if (Platform.isIOS) {
      final AppStoreProductDetails iOSProduct = product as AppStoreProductDetails;
      if (iOSProduct.skProduct.introductoryPrice != null) {
        // Check if introductory price is a discount (not free and less than normal price)
        final introPrice = double.parse(iOSProduct.skProduct.introductoryPrice!.price.toString());
        final normalPrice = double.parse(iOSProduct.skProduct.price.toString());

        if (introPrice > 0 && introPrice < normalPrice) {
          // Format the price with currency symbol
          return iOSProduct.skProduct.introductoryPrice!.priceLocale.currencySymbol + introPrice.toString();
        }
        if (introPrice == 0) {
          return 'Free for ${iOSProduct.skProduct.introductoryPrice!.subscriptionPeriod.numberOfUnits} days';
        }
      }
    }
    return null;
  }

  String _getTrialPeriod(ProductDetails product) {
    if (Platform.isAndroid) {
      final GooglePlayProductDetails googleProduct = product as GooglePlayProductDetails;
      final offerDetails = googleProduct.productDetails.subscriptionOfferDetails;

      if (offerDetails != null && offerDetails.isNotEmpty) {
        final firstPhase = offerDetails.first.pricingPhases.first;
        if (firstPhase.priceAmountMicros == 0) {
          // Format the billing period
          final billingPeriod = firstPhase.billingPeriod;
          if (billingPeriod.contains('D')) {
            final days = billingPeriod.replaceAll('P', '').replaceAll('D', '');
            return '$days-day free trial';
          } else if (billingPeriod.contains('W')) {
            final weeks = billingPeriod.replaceAll('P', '').replaceAll('W', '');
            return '$weeks-week free trial';
          } else if (billingPeriod.contains('M')) {
            final months = billingPeriod.replaceAll('P', '').replaceAll('M', '');
            return '$months-month free trial';
          }
          return 'Free trial';
        }
      }
    } else if (Platform.isIOS) {
      final AppStoreProductDetails iOSProduct = product as AppStoreProductDetails;
      if (iOSProduct.skProduct.introductoryPrice != null && iOSProduct.skProduct.introductoryPrice!.price == 0) {
        final periodUnit = iOSProduct.skProduct.introductoryPrice!.subscriptionPeriod.unit;
        final periodUnits = iOSProduct.skProduct.introductoryPrice!.subscriptionPeriod.numberOfUnits;

        if (periodUnit == SKSubscriptionPeriodUnit.day.index) {
          return '$periodUnits-day free trial';
        } else if (periodUnit == SKSubscriptionPeriodUnit.week.index) {
          return '$periodUnits-week free trial';
        } else if (periodUnit == SKSubscriptionPeriodUnit.month.index) {
          return '$periodUnits-month free trial';
        }
        return 'Free trial';
      }
    }
    return '';
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

  List<Map<String, dynamic>> _getSubscriptionBenefits() {
    return [
      {'icon': Icons.category, 'text': 'Access to all premium categories'},
      {'icon': Icons.auto_awesome, 'text': '10x Lessons creation every day'},
      {'icon': Icons.music_note, 'text': 'Listen to your lesson without ads'},
      {'icon': Icons.star, 'text': 'Priority access to latest features'},
    ];
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 16 : 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(ProductDetails productDetails) {
    bool hasIntro = _hasIntroductoryOffer(productDetails);
    bool hasFreeTrialOffer = hasIntro && _getTrialPeriod(productDetails).isNotEmpty && !_hasUsedTrial;
    String? discountedPrice = _getDiscountedPrice(productDetails);
    bool hasDiscountedPrice = discountedPrice != null && !hasFreeTrialOffer;

    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final benefits = _getSubscriptionBenefits();

    // Define the subscription type label based on product ID
    final String subscriptionType = productDetails.id == "1m" ? "Monthly" : "Annual";
    final bool isAnnual = productDetails.id == "1year";

    // Add savings label for annual subscription
    final Widget? savingsLabel = isAnnual
        ? Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "SAVE 50%",
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          )
        : null;

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isAnnual ? colorScheme.primary.withOpacity(0.4) : colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: isAnnual ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Subscription Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 20,
              vertical: isSmallScreen ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: isAnnual ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.surfaceContainerLow,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 40 : 44,
                  height: isSmallScreen ? 40 : 44,
                  decoration: BoxDecoration(
                    color: isAnnual ? colorScheme.primary.withOpacity(0.2) : colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAnnual ? Icons.star : Icons.star_half,
                    color: colorScheme.primary,
                    size: isSmallScreen ? 22 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "$subscriptionType Premium",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 16 : 18,
                            ),
                          ),
                          if (savingsLabel != null) ...[
                            const SizedBox(width: 8),
                            savingsLabel,
                          ],
                        ],
                      ),
                      if (hasFreeTrialOffer)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "Includes ${_getTrialPeriod(productDetails)}",
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: isSmallScreen ? 12 : 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Benefits List
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Benefits Section
                ...benefits.map((benefit) => _buildBenefitItem(benefit['icon'], benefit['text'])),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Price Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAnnual ? colorScheme.primary : colorScheme.primaryContainer,
                        foregroundColor: isAnnual ? colorScheme.onPrimary : colorScheme.primary,
                        elevation: isAnnual ? 2 : 0,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _makePurchase(productDetails),
                      child: Column(
                        children: [
                          Text(
                            hasFreeTrialOffer
                                ? 'Start Free Trial'
                                : hasDiscountedPrice
                                    ? discountedPrice
                                    : productDetails.price,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 16 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasDiscountedPrice)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                productDetails.price,
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: isAnnual ? colorScheme.onPrimary.withOpacity(0.7) : colorScheme.primary.withOpacity(0.7),
                                ),
                              ),
                            ),
                          if (!hasFreeTrialOffer && !hasDiscountedPrice)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                productDetails.id == "1m" ? "Billed monthly" : "Billed annually",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: isAnnual ? colorScheme.onPrimary.withOpacity(0.8) : colorScheme.primary.withOpacity(0.8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
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

    return Container(
      margin: EdgeInsets.only(
        top: isSmallScreen ? 12 : 24,
        bottom: isSmallScreen ? 16 : 24,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Container(
            width: isSmallScreen ? 64 : 80,
            height: isSmallScreen ? 64 : 80,
            decoration: BoxDecoration(
              color: _hasPremium ? colorScheme.primaryContainer : colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _hasPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              size: isSmallScreen ? 36 : 44,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          Text(
            _hasPremium ? 'You\'re Premium!' : 'Upgrade to Premium',
            style: TextStyle(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          Text(
            _hasPremium ? 'Enjoy all premium features and benefits' : 'Choose the plan that works best for you',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRestoreButton() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 24,
            vertical: isSmallScreen ? 12 : 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _inAppPurchase.restorePurchases(),
        icon: Icon(
          Icons.restore,
          size: isSmallScreen ? 18 : 20,
        ),
        label: Text(
          'Restore Purchases',
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmallScreen ? 12 : 16,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _launchURL(Uri(
                  scheme: "https",
                  host: "gregarious-giant-4a5.notion.site",
                  path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26",
                )),
                child: Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                ),
              ),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onSurfaceVariant,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _launchURL(Uri.parse("https://parakeet.world/privacypolicy")),
                child: Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Subscription will automatically renew unless canceled',
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
          "Premium",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeader(),
                    if (_notice != null)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _notice!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: isSmallScreen ? 14 : 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_hasPremium && _products.isNotEmpty) ..._getUniqueProducts().map(_buildSubscriptionCard),
                    if (!_hasPremium) _buildRestoreButton(),
                    _buildFooterLinks(),
                    SizedBox(height: isSmallScreen ? 16 : 24),
                  ],
                ),
              ),
      ),
    );
  }
}
