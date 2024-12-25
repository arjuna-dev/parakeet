import 'package:speech_to_text/speech_to_text.dart';
import 'package:parakeet/utils/flutter_stt_language_codes.dart';
import 'package:flutter/foundation.dart';

class SpeechToTextUltra {
  late SpeechToText _speech;
  bool isListening = false;
  String liveResponse = '';
  String entireResponse = '';
  String chunkResponse = '';
  String languageName = '';
  String languageCode = '';

  final Function(String liveText, String finalText, bool isListening) ultraCallback;
  // Reference _checkIfLanguageSupported function to check if the target language is supported

  SpeechToTextUltra({required this.ultraCallback, required this.languageName}) {
    _speech = SpeechToText();
    // TODO: Add error handling
    languageCode = languageCodes[languageName] ?? '';
  }

  Future<SpeechToText> startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) async {
        if ((status == "done" || status == "notListening") && isListening) {
          await _speech.stop();
          if (chunkResponse != '') {
            entireResponse = '$entireResponse $chunkResponse';
          }
          chunkResponse = '';
          liveResponse = '';
          isListening = false;
          ultraCallback(liveResponse, entireResponse, isListening);
          await startListening();
        }
      },
    );

    if (available) {
      isListening = true;
      liveResponse = '';
      chunkResponse = '';
      ultraCallback(liveResponse, entireResponse, isListening);
      await _speech.listen(
        onResult: (result) {
          liveResponse = result.recognizedWords;
          if (result.finalResult) {
            chunkResponse = result.recognizedWords;
          }
          ultraCallback(liveResponse, entireResponse, isListening);
        },
        localeId: languageCode,
      );
    } else {
      throw Exception('Speech recognition not available');
    }
    return _speech;
  }

  void stopListening() async {
    await _speech.stop();
    isListening = false;
    entireResponse = '$entireResponse $chunkResponse';
    ultraCallback(liveResponse, entireResponse, isListening);
  }

  Future<bool> checkIfLanguageSupported(speechInstance) async {
    bool isLanguageSupported;
    List<LocaleName> systemLocales;

    if (kIsWeb) {
      // TODO: do we need to check for language support on web?
      return true;
    } else {
      // Get system locales from the device
      systemLocales = await speechInstance.locales();

      // Convert target language code to match system locale format
      // String? targetLanguageCode = languageCodes[languageName]?.replaceAll('-', '_');
      String? targetLanguageCode = languageCodes[languageName];

      isLanguageSupported = systemLocales.any((locale) => locale.localeId == targetLanguageCode);
      return isLanguageSupported;
    }
  }

  void dispose() {
    stopListening();
  }
}
