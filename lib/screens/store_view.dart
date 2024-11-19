import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreView extends StatefulWidget {
  const StoreView({super.key});

  @override
  State<StoreView> createState() => _StoreViewState();
}

const List<String> _productIds = <String>[
  '1m',
];

class _StoreViewState extends State<StoreView> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  bool _isAvailable = false;
  String? _notice;
  List<ProductDetails> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    initStoreInfo();
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
    ProductDetailsResponse productDetailsResponse =
        await _inAppPurchase.queryProductDetails(_productIds.toSet());

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_notice!),
              ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),
            Expanded(
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final ProductDetails productDetails = _products[index];

                  return Card(
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _getIAPIcon(productDetails.id),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    8.0, 25.0, 8.0, 8.0),
                                child: Text(
                                  productDetails.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    8.0, 8.0, 8.0, 8.0),
                                child: Text(
                                  productDetails.description,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: _buyText(productDetails),
                            onPressed: () {
                              late PurchaseParam purchaseParam;

                              if (Platform.isAndroid) {
                                purchaseParam = GooglePlayPurchaseParam(
                                    productDetails: productDetails,
                                    changeSubscriptionParam: null);
                              } else {
                                purchaseParam = PurchaseParam(
                                    productDetails: productDetails);
                              }

                              if (productDetails.id == "1m") {
                                InAppPurchase.instance.buyNonConsumable(
                                    purchaseParam: purchaseParam);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _buildRestoreButton(),
            _buildTermsButton(),
            _buildPrivacyButton(),
          ],
        ),
      ),
    );
  }

  Widget _getIAPIcon(productId) {
    if (productId == "1m" || productId == "1y" || productId == "1year") {
      return const Icon(Icons.subscriptions_rounded, size: 25);
    } else {
      return const Icon(Icons.post_add_outlined, size: 50);
    }
  }

  Widget _buyText(productDetails) {
    if (productDetails.id == "1m") {
      return Text("${productDetails.price} / month");
    } else if (productDetails.id == "1y" || productDetails.id == "1year") {
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

  Widget _buildTermsButton() {
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
          onPressed: () => _launchURL(Uri(
              scheme: "https",
              host: "gregarious-giant-4a5.notion.site",
              path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26")),
          child: const Text('Terms and Conditions'),
        )
      ],
    );
  }

  Widget _buildPrivacyButton() {
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
          onPressed: () =>
              _launchURL(Uri.parse("https://parakeet.world/privacypolicy")),
          child: const Text('Privacy Policy'),
        )
      ],
    );
  }

  void _launchURL(Uri url) async {
    await canLaunchUrl(url)
        ? await launchUrl(url)
        : throw 'Could not launch $url';
  }
}
