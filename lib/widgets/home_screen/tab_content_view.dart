import 'package:flutter/material.dart';
import 'package:parakeet/utils/constants.dart';

class TabContentView extends StatelessWidget {
  final Widget child;
  final bool isSmallScreen;

  const TabContentView({
    Key? key,
    required this.child,
    required this.isSmallScreen,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = isSmallScreen ? 8.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.horizontalPadding.left,
        vertical: padding,
      ),
      child: child,
    );
  }
}
