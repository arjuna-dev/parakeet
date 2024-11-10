import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AppConstants {
  // Define standard padding for the app
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets horizontalPadding =
      EdgeInsets.symmetric(horizontal: 16.0);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final Uri urlIOS = Uri.parse('https://apps.apple.com/app/6618158139');
final Uri urlAndroid = Uri.parse(
    'https://play.google.com/store/apps/details?id=com.parakeetapp.app');
final Uri urlWebApp = Uri.parse('https://app.parakeet.world');

void launchURL(Uri url) async {
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
}
