import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
// ignore: depend_on_referenced_packages
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

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
                                child: Text(productDetails.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                              ),
                              Text(productDetails.description),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
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
          ],
        ),
      ),
    );
  }

  Widget _getIAPIcon(productId) {
    if (productId == "1m") {
      return const Icon(Icons.subscriptions_rounded, size: 25);
    } else {
      return const Icon(Icons.post_add_outlined, size: 50);
    }
  }

  Widget _buyText(productDetails) {
    if (productDetails.id == "1m") {
      return Text("${productDetails.price} / month");
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
          child: Text('Restore Purchases'),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor),
          onPressed: () => _inAppPurchase.restorePurchases(),
        )
      ],
    );
  }
}
