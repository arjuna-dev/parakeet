import 'dart:math';
import 'package:http/http.dart' as http;

class AudioUrlBuilder {
  final String documentID;
  final String userID;
  final String nativeLanguage;
  final bool hasNicknameAudio;
  final bool addressByNickname;

  AudioUrlBuilder({
    required this.documentID,
    required this.userID,
    required this.nativeLanguage,
    required this.hasNicknameAudio,
    required this.addressByNickname,
  });

  /// Constructs the appropriate URL for a given filename
  Future<String> constructUrl(String fileName) async {
    if (fileName.startsWith("https://")) {
      return fileName;
    } else if (_isNarratorFile(fileName)) {
      // narrator_, one_second_break, five_second_break
      return _getNarratorUrl(fileName);
    } else if (fileName == "nickname") {
      // nickname logic
      return await _getNicknameUrl();
    } else if (fileName == "audio_cue") {
      // audio_cue
      return _getAudioCueUrl();
    } else {
      // default conversation audio
      return _getConversationAudioUrl(fileName);
    }
  }

  /// Returns `true` if the filename indicates a "narrator" or a break file.
  bool _isNarratorFile(String fileName) {
    return fileName.startsWith("narrator_") || fileName == "one_second_break" || fileName == "five_second_break";
  }

  /// Builds the URL for narrator/break files.
  String _getNarratorUrl(String fileName) {
    return "https://storage.googleapis.com/narrator_audio_files/"
        "google_tts/narrator_$nativeLanguage/$fileName.mp3";
  }

  /// Builds the URL for nickname files or, if unavailable, returns a generic greeting URL.
  Future<String> _getNicknameUrl() async {
    final bool canUseNickname = hasNicknameAudio && addressByNickname;
    print('canUseNickname: $canUseNickname');

    if (canUseNickname) {
      final List<int> numbers = List.generate(5, (i) => i)..shuffle();
      for (final randomNumber in numbers) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final url = "https://storage.googleapis.com/user_nicknames/"
            "${userID}_${nativeLanguage}_${randomNumber + 1}_nickname.mp3?timestamp=$timestamp";

        if (await urlExists(url)) {
          return url; // Return first valid URL
        }
      }
    }

    // If we can't (or didn't) find a nickname file, return a generic greeting.
    return _getGenericGreetingUrl();
  }

  /// Returns the URL to a generic greeting.
  String _getGenericGreetingUrl() {
    final randomNumber = Random().nextInt(5) + 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "https://storage.googleapis.com/narrator_audio_files/"
        "google_tts/narrator_${Uri.encodeComponent(nativeLanguage)}/"
        "narrator_greetings_$randomNumber.mp3?timestamp=$timestamp";
  }

  /// Builds the URL for the audio cue file.
  String _getAudioCueUrl() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "https://storage.googleapis.com/narrator_audio_files/"
        "general/audio_cue.mp3?timestamp=$timestamp";
  }

  /// Builds the URL for the default (conversation) audio files.
  String _getConversationAudioUrl(String fileName) {
    return "https://storage.googleapis.com/conversations_audio_files/"
        "$documentID/$fileName.mp3";
  }

  /// Checks if a URL exists by making a HEAD request
  static Future<bool> urlExists(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print('Error checking URL existence: $e');
      return false;
    }
  }

  /// Retries checking if a URL exists multiple times
  static Future<bool> retryUrlExists(String url, {int retries = 10, Duration delay = const Duration(seconds: 1)}) async {
    for (int i = 1; i <= retries; i++) {
      bool exists = await urlExists(url);
      if (exists) {
        return true;
      }
      await Future.delayed(delay);
    }
    return false;
  }
}
