import 'dart:io';
import 'dart:async';

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
  bool _purchaseInProgress = false;
  String _selectedSubscription = "1m"; // Default to monthly subscription

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

      setState(() {
        _hasPremium = isPremium;
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

  String? _getOriginalProductPriceForAndroid(ProductDetails product) {
    if (Platform.isAndroid) {
      final GooglePlayProductDetails googleProduct = product as GooglePlayProductDetails;
      return googleProduct.productDetails.subscriptionOfferDetails?.first.pricingPhases.last.formattedPrice;
    }
    return null;
  }

  String? _getDiscountedPrice(ProductDetails product) {
    if (Platform.isAndroid) {
      final GooglePlayProductDetails googleProduct = product as GooglePlayProductDetails;
      print("google product: ${googleProduct.rawPrice}");

      final offerDetails = googleProduct.productDetails.subscriptionOfferDetails;

      if (offerDetails != null && offerDetails.isNotEmpty) {
        print("offerDetailsAndroid: ${offerDetails.length}");
        final phases = offerDetails.first.pricingPhases;
        if (phases.length > 1) {
          final discountedFormattedPrice = phases.first.formattedPrice;
          final discountedRawPrice = phases.first.priceAmountMicros;
          if (discountedFormattedPrice == "Free" || discountedRawPrice == 0) {
            final billingPeriod = phases.first.billingPeriod;
            final billingPeriodNumber = phases.first.billingPeriod.replaceAll("P", "").replaceAll("D", "").replaceAll("W", "").replaceAll("M", "").replaceAll("Y", "");
            // if billingPeriod has W, return "billingPeriodNumber days"
            if (billingPeriod.contains("D")) {
              return "Free for $billingPeriodNumber days";
            } else if (billingPeriod.contains("W")) {
              return "Free for $billingPeriodNumber weeks";
            } else if (billingPeriod.contains("M")) {
              return "Free for $billingPeriodNumber months";
            } else if (billingPeriod.contains("Y")) {
              return "Free for $billingPeriodNumber years";
            }
          }
          return discountedFormattedPrice;
        }
      }
    } else if (Platform.isIOS) {
      final AppStoreProductDetails iOSProduct = product as AppStoreProductDetails;
      if (iOSProduct.skProduct.introductoryPrice != null) {
        // Check if introductory price is a discount (not free and less than normal price)
        final introPrice = double.parse(iOSProduct.skProduct.introductoryPrice!.price.toString());
        final normalPrice = double.parse(iOSProduct.skProduct.price.toString());
        final symbol = iOSProduct.skProduct.priceLocale.currencySymbol;

        String period = '';
        switch (product.id) {
          case "1m":
            period = 'month';
            break;
          case "1year":
            period = 'year';
            break;
          default:
            period = 'period';
        }

        if (introPrice > 0 && introPrice < normalPrice) {
          // Format the price with currency symbol
          return '$symbol${introPrice.toString()}/$period';
        }
        if (introPrice == 0) {
          final units = iOSProduct.skProduct.introductoryPrice!.subscriptionPeriod.numberOfUnits;
          return 'Free for $units days';
        }
      }
    }
    return null;
  }

  String? _getRenewalText(ProductDetails product) {
    if (Platform.isIOS) {
      final AppStoreProductDetails iOSProduct = product as AppStoreProductDetails;
      if (iOSProduct.skProduct.introductoryPrice != null) {
        String period = '';
        switch (product.id) {
          case "1m":
            period = 'month';
            break;
          case "1year":
            period = 'year';
            break;
          default:
            period = 'period';
        }

        return '• renews at ${product.price}/$period • Cancel anytime';
      }
    }
    return null;
  }

  Future<void> _makePurchase(ProductDetails productDetails) async {
    setState(() {
      _purchaseInProgress = true;
    });

    late PurchaseParam purchaseParam;

    if (Platform.isAndroid) {
      purchaseParam = GooglePlayPurchaseParam(productDetails: productDetails, changeSubscriptionParam: null);
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    if (productDetails.id == "1m" || productDetails.id == "1year") {
      // Create a stream subscription to listen for purchase updates
      late StreamSubscription<List<PurchaseDetails>> subscription;
      subscription = _inAppPurchase.purchaseStream.listen(
        (List<PurchaseDetails> purchases) async {
          for (final purchase in purchases) {
            if (purchase.status == PurchaseStatus.purchased) {
              // Complete the purchase
              await _inAppPurchase.completePurchase(purchase);

              // Update Firestore with the new subscription information
              try {
                final userId = FirebaseAuth.instance.currentUser?.uid;
                if (userId != null) {
                  // We don't need to wait for this to complete before showing success to the user
                  FirebaseFirestore.instance.collection('users').doc(userId).update({
                    'premium': true,
                    'subscriptionType': productDetails.id,
                  });
                }
              } catch (e) {
                print("Error updating user premium status: $e");
              }

              // Cancel the subscription after successful processing
              subscription.cancel();

              if (mounted) {
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchase successful! You now have premium access.'),
                    backgroundColor: Colors.green,
                  ),
                );

                // Reset loading state
                setState(() {
                  _purchaseInProgress = false;
                });

                // Reload the page by refreshing the state
                await checkPremiumStatus();
              }
            } else if (purchase.status == PurchaseStatus.error) {
              // Show error message
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Purchase failed. Please try again.')),
                );
                setState(() {
                  _purchaseInProgress = false;
                });
              }
              subscription.cancel();
            } else if (purchase.status == PurchaseStatus.canceled) {
              if (mounted) {
                setState(() {
                  _purchaseInProgress = false;
                });
              }
              subscription.cancel();
            }
          }
        },
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Purchase failed: $error')),
            );
            setState(() {
              _purchaseInProgress = false;
            });
          }
          subscription.cancel();
        },
      );

      // Initiate the purchase
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
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
      {'icon': Icons.speaker_group, 'text': 'Access to premium voices'},
      {'icon': Icons.auto_awesome, 'text': 'Generate 10 lessons per day'},
      {'icon': Icons.music_note, 'text': 'Listen to your lesson without ads'},
      {'icon': Icons.star, 'text': 'Priority access to new features'},
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

  Widget _buildCombinedSubscriptionCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final benefits = _getSubscriptionBenefits();

    // Get product details for monthly and annual subscriptions
    ProductDetails? monthlyProduct;
    ProductDetails? annualProduct;

    // Find products safely
    for (var product in _products) {
      if (product.id == "1m") {
        monthlyProduct = product;
      } else if (product.id == "1year") {
        annualProduct = product;
      }
    }

    // Fallback if products aren't found
    monthlyProduct ??= _products.isNotEmpty ? _products.first : null;
    annualProduct ??= _products.isNotEmpty ? _products.last : monthlyProduct;

    // Safety check - if we don't have products, return an empty container
    if (monthlyProduct == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            "No subscription products available",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    // Get the currently selected product
    final selectedProduct = _selectedSubscription == "1m" ? monthlyProduct : (annualProduct ?? monthlyProduct);

    String? discountedPrice = _getDiscountedPrice(selectedProduct);
    String? renewalText = _getRenewalText(selectedProduct);
    bool hasDiscountedPrice = discountedPrice != null;
    bool hasRenewalText = renewalText != null;

    // Define the subscription type label based on product ID
    final String subscriptionType = _selectedSubscription == "1m" ? "Monthly" : "Annual";
    final bool isAnnual = _selectedSubscription == "1year";

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
              "SAVE 65%",
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
          color: colorScheme.primary.withOpacity(0.4),
          width: 2,
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
              color: colorScheme.primaryContainer.withOpacity(0.5),
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
                    color: colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
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
                            "Premium",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 16 : 18,
                            ),
                          ),
                          if (savingsLabel != null && isAnnual) ...[
                            const SizedBox(width: 8),
                            savingsLabel,
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Subscription Toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSubscription = "1m";
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedSubscription == "1m" ? colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            "Monthly",
                            style: TextStyle(
                              fontWeight: _selectedSubscription == "1m" ? FontWeight.bold : FontWeight.normal,
                              color: _selectedSubscription == "1m" ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSubscription = "1year";
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedSubscription == "1year" ? colorScheme.primaryContainer : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                "Annual",
                                style: TextStyle(
                                  fontWeight: _selectedSubscription == "1year" ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedSubscription == "1year" ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "65% OFF",
                                style: TextStyle(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 2,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _purchaseInProgress ? null : () => _makePurchase(selectedProduct),
                      child: _purchaseInProgress
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: colorScheme.onPrimary,
                                strokeWidth: 2,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (hasDiscountedPrice)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          discountedPrice,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 14 : 16,
                                          ),
                                        ),
                                      ),
                                      if (hasRenewalText)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            renewalText,
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 10 : 11,
                                              color: colorScheme.onPrimary.withOpacity(0.7),
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          // check the platform and return the correct price
                                          Platform.isAndroid ? _getOriginalProductPriceForAndroid(selectedProduct)! : selectedProduct.price,
                                          style: TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            fontSize: isSmallScreen ? 12 : 13,
                                            color: colorScheme.onPrimary.withOpacity(0.7),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!hasDiscountedPrice)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      selectedProduct.price,
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 14 : 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
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
          _buildCurrentMembershipStatus(),
        ],
      ),
    );
  }

  Widget _buildCurrentMembershipStatus() {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).get(),
      builder: (context, snapshot) {
        // Default values
        String membershipType = _hasPremium ? "Premium" : "Free";

        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;

          if (userData != null && _hasPremium) {
            // Get subscription type if available
            if (userData['subscriptionType'] != null) {
              membershipType = userData['subscriptionType'] == "1year" ? "Annual Premium" : "Monthly Premium";
            }
          }
        }

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: _hasPremium ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasPremium ? colorScheme.primary.withOpacity(0.3) : colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _hasPremium ? Icons.card_membership : Icons.person_outline,
                size: 18,
                color: _hasPremium ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                membershipType,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _hasPremium ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
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
                            color: _hasPremium ? colorScheme.primaryContainer.withOpacity(0.5) : colorScheme.errorContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _hasPremium ? Icons.check_circle_outline : Icons.info_outline,
                                color: _hasPremium ? colorScheme.primary : colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _notice!,
                                  style: TextStyle(
                                    color: _hasPremium ? colorScheme.onPrimaryContainer : colorScheme.onErrorContainer,
                                    fontSize: isSmallScreen ? 14 : 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_hasPremium && _products.isNotEmpty) _buildCombinedSubscriptionCard(),
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
