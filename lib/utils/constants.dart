import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

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

enum TTSProvider {
  googleTTS(1),
  openAI(3),
  elevenLabs(2);

  final int value;
  const TTSProvider(this.value);
}

Future<bool> urlExists(String url) async {
  try {
    final response = await http.head(Uri.parse(url));
    return response.statusCode == 200;
  } catch (e) {
    print("Error checking URL existence: $e");
    return false;
  }
}
