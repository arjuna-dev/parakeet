// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:parakeet/utils/speech_recognition.dart';
// import 'package:parakeet/utils/supported_language_codes.dart';
// import 'package:parakeet/utils/vosk_recognizer.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'package:string_similarity/string_similarity.dart';
// import 'dart:math';
// import 'package:parakeet/utils/constants.dart';

// class SpeechRecognitionService {
//   final String targetLanguage;
//   final String nativeLanguage;

//   late SpeechToTextUltra speechToTextUltra;
//   SpeechService? voskSpeechService;

//   bool isLanguageSupported = false;
//   bool speechRecognitionActive = false;
//   String liveTextSpeechToText = '';
//   String? targetPhraseToCompareWith;
//   bool isSliderMoving = false;
//   bool isSkipping = false;

//   // Callback for speech recognition status changes
//   final ValueChanged<String> onLiveTextChanged;

//   SpeechRecognitionService({
//     required this.targetLanguage,
//     required this.nativeLanguage,
//     required this.onLiveTextChanged,
//   }) {
//     speechToTextUltra = SpeechToTextUltra(
//       languageName: targetLanguage,
//       ultraCallback: _handleSpeechCallback,
//     );
//   }

//   // Handle speech recognition callback
//   void _handleSpeechCallback(String liveText, String finalText, bool isListening) {
//     liveTextSpeechToText = liveText;
//     onLiveTextChanged(liveText);
//   }

//   // Initialize speech recognition
//   Future<bool> initializeSpeechRecognition() async {
//     // If device is Android initialize vosk
//     if (!kIsWeb && Platform.isAndroid) {
//       await _initVosk();
//       return isLanguageSupported;
//     }

//     // Initialize the speech recognition for iOS/Web
//     SpeechToText speechRecognition = await speechToTextUltra.startListening();

//     // Check if the specified language is supported
//     isLanguageSupported = await speechToTextUltra.checkIfLanguageSupported(speechRecognition);

//     return isLanguageSupported;
//   }

//   // Initialize Vosk for Android
//   Future<void> _initVosk() async {
//     try {
//       VoskFlutterPlugin vosk = VoskFlutterPlugin.instance();
//       String? voskModelUrl = getVoskModelUrl(targetLanguage);
//       if (voskModelUrl == null) {
//         isLanguageSupported = false;
//         return;
//       } else {
//         isLanguageSupported = true;
//       }

//       Future<String> enSmallModelPath = ModelLoader().loadFromNetwork(voskModelUrl);
//       Future<Model> voskModel = vosk.createModel(await enSmallModelPath);

//       final recognizer = await vosk.createRecognizer(
//         model: await voskModel,
//         sampleRate: 16000,
//       );

//       voskSpeechService = await vosk.initSpeechService(recognizer);
//       voskSpeechService!.onResult().forEach((result) {
//         final String resultText = jsonDecode(result)['text'];
//         print("result: $resultText");
//         liveTextSpeechToText = resultText;
//         onLiveTextChanged(resultText);
//       });

//       await voskSpeechService!.start();
//     } catch (e) {
//       print('Error initializing Vosk: $e');
//       isLanguageSupported = false;
//       speechRecognitionActive = false;
//     }
//   }

//   // Get Vosk model URL for the target language
//   String? getVoskModelUrl(String languageName) {
//     // Get full language code (e.g., "en-US")
//     final fullCode = supportedLanguageCodes[languageName];
//     if (fullCode == null) {
//       return null;
//     }

//     // Extract base language code (e.g., "en" from "en-US")
//     if (fullCode == 'en-US' || fullCode == 'en-GB') {
//       return voskModelUrls[fullCode];
//     }

//     final partialCode = fullCode.split('-')[0].toLowerCase();

//     // Return URL if exists, null otherwise
//     return voskModelUrls[partialCode];
//   }

//   // Compare speech with target phrase
//   Future<bool> compareSpeechWithPhrase([String? stringWhenStarting]) async {
//     if (targetPhraseToCompareWith == null || isSliderMoving) {
//       return false;
//     }

//     String normalizedLiveTextSpeechToText = _normalizeString(liveTextSpeechToText);

//     String newSpeech;
//     if ((kIsWeb || Platform.isIOS) && stringWhenStarting != null) {
//       print("liveTextSpeechToText: $liveTextSpeechToText");
//       print("stringWhenStarting: $stringWhenStarting");
//       String normalizedStringWhenStarting = _normalizeString(stringWhenStarting);
//       newSpeech = getAddedCharacters(normalizedLiveTextSpeechToText, normalizedStringWhenStarting);
//     } else {
//       newSpeech = normalizedLiveTextSpeechToText;
//     }

//     print("newSpeech: $newSpeech");

//     if (newSpeech == '') {
//       print("NO audio was detected!!!");
//       return false;
//     }

//     // Normalize both strings: remove punctuation and convert to lowercase
//     String normalizedResponse = _normalizeString(newSpeech);
//     // Duplicate normalizedResponse for web doubled text bug
//     String doubledNormalizedResponse = '$normalizedResponse $normalizedResponse';
//     String normalizedTargetPhrase = _normalizeString(targetPhraseToCompareWith!);

//     print('you said: $normalizedResponse, timestamp: ${DateTime.now().toIso8601String()}');
//     print('target phrase: $normalizedTargetPhrase, timestamp: ${DateTime.now().toIso8601String()}');

//     // Calculate similarity
//     double similarity = StringSimilarity.compareTwoStrings(
//       normalizedResponse,
//       normalizedTargetPhrase,
//     );

//     double similarityForDoubled = StringSimilarity.compareTwoStrings(
//       doubledNormalizedResponse,
//       normalizedTargetPhrase,
//     );

//     if (similarityForDoubled > similarity) {
//       similarity = similarityForDoubled;
//     }

//     print('Similarity: $similarity');

//     return similarity >= 0.7;
//   }

//   // Get added characters between two strings
//   String getAddedCharacters(String newString, String previousString) {
//     // Split the strings into word lists
//     List<String> newWords = newString.split(RegExp(r'\s+'));
//     List<String> previousWords = previousString.split(RegExp(r'\s+'));

//     // Compare word-by-word and find differences
//     int minLength = previousWords.length;
//     for (int i = 0; i < minLength; i++) {
//       if (newWords[i] != previousWords[i]) {
//         // Word has been replaced; return from this point onward
//         return newWords.skip(i).join(' ');
//       }
//     }

//     // If all previous words match, return the new additions
//     if (newWords.length > previousWords.length) {
//       return newWords.skip(previousWords.length).join(' ');
//     }

//     // If no new words are detected, return an empty string
//     return "";
//   }

//   // Normalize string for comparison
//   String _normalizeString(String input) {
//     // Remove punctuation but preserve Unicode letters including Devanagari
//     return input.replaceAll(RegExp(r'[^\p{L}\p{N}\s]+', unicode: true), '').toLowerCase();
//   }

//   // Provide audio feedback based on comparison result
//   Future<void> provideFeedback({required bool isPositive}) async {
//     // Create a separate AudioPlayer for feedback
//     AudioPlayer feedbackPlayer = AudioPlayer();

//     // Get the feedback audio URL
//     String feedbackUrl = _getFeedbackAudioUrl(isPositive);
//     print('Playing feedback audio from: $feedbackUrl');

//     // Set the audio source using the cloud URL
//     await feedbackPlayer.setAudioSource(
//       AudioSource.uri(Uri.parse(feedbackUrl)),
//     );

//     // Play the feedback
//     await feedbackPlayer.play();

//     // Release the feedback player resources
//     await feedbackPlayer.dispose();
//   }

//   // Get random feedback audio URL
//   String _getFeedbackAudioUrl(bool isPositive) {
//     final random = Random();
//     final num = isPositive ? random.nextInt(3) : random.nextInt(2) + 3; // 0-2 for positive, 3-4 for negative
//     return 'https://storage.googleapis.com/pronunciation_feedback/feedback_${nativeLanguage}_${isPositive ? "positive" : "negative"}_$num.mp3';
//   }

//   // Set target phrase to compare with
//   void setTargetPhraseToCompareWith(String phrase) {
//     targetPhraseToCompareWith = phrase;
//   }

//   // Reset speech recognition
//   void reset() {
//     if (voskSpeechService != null) {
//       voskSpeechService!.reset();
//     }
//   }

//   // Stop speech recognition
//   void stopListening() {
//     if (kIsWeb || Platform.isIOS) {
//       speechToTextUltra.stopListening();
//     } else if (!kIsWeb && Platform.isAndroid && voskSpeechService != null) {
//       voskSpeechService!.stop();
//     }

//     speechRecognitionActive = false;
//   }

//   // Dispose resources
//   void dispose() {
//     if (!kIsWeb && Platform.isAndroid && voskSpeechService != null) {
//       voskSpeechService!.stop();
//       voskSpeechService!.dispose();
//       voskSpeechService = null;
//     } else {
//       speechToTextUltra.dispose();
//     }
//   }
// }
