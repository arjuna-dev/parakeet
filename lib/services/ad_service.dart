import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdService {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;
  static const int playCountThreshold = 3;
  static final adUnitId = Platform.isAndroid
      ? 'ca-app-pub-8442868776505925/6924045775'
      : 'ca-app-pub-8442868776505925/7219559244';

  static Future<void> initialize() async {
    await loadInterstitialAd();
  }

  static Future<void> loadInterstitialAd() async {
    if (_isAdLoading) return;
    _isAdLoading = true;

    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
        },
      ),
    );
  }

  static Future<void> showInterstitialAd({
    Function? onAdDismissed,
    Function? onAdShown,
  }) async {
    if (_interstitialAd == null) {
      print('Warning: attempt to show ad before loaded');
      onAdDismissed?.call(); // Call callback even if ad isn't available
      await loadInterstitialAd(); // Try to load for next time
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load the next ad
        onAdDismissed?.call(); // Call the callback when ad is dismissed
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Load the next ad
        onAdDismissed?.call(); // Call the callback even if ad fails
      },
      onAdShowedFullScreenContent: (ad) {
        _interstitialAd = ad;
        onAdShown?.call();
      },
    );

    await _interstitialAd!.show();
  }

  static Future<bool> shouldShowAd() async {
    final prefs = await SharedPreferences.getInstance();
    int playCount = prefs.getInt('audio_play_count') ?? 0;
    return playCount % playCountThreshold == 0 && playCount > 0;
  }

  static Future<void> incrementPlayCount() async {
    final prefs = await SharedPreferences.getInstance();
    int playCount = prefs.getInt('audio_play_count') ?? 0;
    await prefs.setInt('audio_play_count', playCount + 1);
  }
}
