import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class AppConstants {
  // Define standard padding for the app
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(horizontal: 16.0);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final Uri urlIOS = Uri.parse('https://apps.apple.com/app/6618158139');
final Uri urlAndroid = Uri.parse('https://play.google.com/store/apps/details?id=com.parakeetapp.app');
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

final Map<String, String> voskModelUrls = {
  'ar': 'https://alphacephei.com/vosk/models/vosk-model-small-ar-0.3.zip',
  'ar-tn': 'https://alphacephei.com/vosk/models/vosk-model-small-ar-tn-0.1-linto.zip',
  'ca': 'https://alphacephei.com/vosk/models/vosk-model-small-ca-0.4.zip',
  'cn': 'https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip',
  'cs': 'https://alphacephei.com/vosk/models/vosk-model-small-cs-0.4-rhasspy.zip',
  'de': 'https://alphacephei.com/vosk/models/vosk-model-small-de-0.15.zip',
  'en-gb': 'https://alphacephei.com/vosk/models/vosk-model-small-en-gb-0.15.zip',
  'en-in': 'https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip',
  'en-us': 'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
  'eo': 'https://alphacephei.com/vosk/models/vosk-model-small-eo-0.42.zip',
  'es': 'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip',
  'fa': 'https://alphacephei.com/vosk/models/vosk-model-small-fa-0.42.zip',
  'fr': 'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
  'gu': 'https://alphacephei.com/vosk/models/vosk-model-small-gu-0.42.zip',
  'hi': 'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip',
  'it': 'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip',
  'ja': 'https://alphacephei.com/vosk/models/vosk-model-small-ja-0.22.zip',
  'ko': 'https://alphacephei.com/vosk/models/vosk-model-small-ko-0.22.zip',
  'kz': 'https://alphacephei.com/vosk/models/vosk-model-small-kz-0.15.zip',
  'nl': 'https://alphacephei.com/vosk/models/vosk-model-small-nl-0.22.zip',
  'pl': 'https://alphacephei.com/vosk/models/vosk-model-small-pl-0.22.zip',
  'pt': 'https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip',
  'ru': 'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip',
  'sv': 'https://alphacephei.com/vosk/models/vosk-model-small-sv-rhasspy-0.15.zip',
  'te': 'https://alphacephei.com/vosk/models/vosk-model-small-te-0.42.zip',
  'tg': 'https://alphacephei.com/vosk/models/vosk-model-small-tg-0.22.zip',
  'tr': 'https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip',
  'uk': 'https://alphacephei.com/vosk/models/vosk-model-small-uk-v3-small.zip',
  'uz': 'https://alphacephei.com/vosk/models/vosk-model-small-uz-0.22.zip',
  'vn': 'https://alphacephei.com/vosk/models/vosk-model-small-vn-0.4.zip',
};

enum RepetitionMode { normal, less }
