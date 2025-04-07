import 'dart:math';
import 'constants.dart';

Future<String> constructUrl(String fileName, String documentId, String nativeLanguage, String userId) async {
  if (fileName.startsWith("https://")) {
    return fileName;
  } else if (isNarratorFile(fileName)) {
    // narrator_, one_second_break, five_second_break
    return getNarratorUrl(fileName, nativeLanguage);
  } else if (fileName == "nickname") {
    // nickname logic
    return await getNicknameUrl(nativeLanguage, userId);
  } else if (fileName == "audio_cue") {
    // audio_cue
    return getAudioCueUrl();
  } else {
    // default conversation audio
    return getConversationAudioUrl(fileName, documentId);
  }
}

/// Returns `true` if the filename indicates a "narrator" or a break file.
bool isNarratorFile(String fileName) {
  return fileName.startsWith("narrator_") || fileName == "one_second_break" || fileName == "five_second_break";
}

/// Builds the URL for narrator/break files.
String getNarratorUrl(String fileName, String nativeLanguage) {
  return "https://storage.googleapis.com/narrator_audio_files/"
      "google_tts/narrator_$nativeLanguage/$fileName.mp3";
}

/// Builds the URL for nickname files or, if unavailable, returns a generic greeting URL.
Future<String> getNicknameUrl(String nativeLanguage, String userId) async {
  final List<int> numbers = List.generate(6, (i) => i)..shuffle();
  for (final randomNumber in numbers) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final url = "https://storage.googleapis.com/user_nicknames/"
        "${userId}_${randomNumber}_nickname.mp3?timestamp=$timestamp";
    if (await urlExists(url)) {
      return url;
    }
  }

  // If we can’t (or didn’t) find a nickname file, return a generic greeting.
  return getGenericGreetingUrl(nativeLanguage);
}

/// Returns the URL to a generic greeting.
String getGenericGreetingUrl(String nativeLanguage) {
  final randomNumber = Random().nextInt(5) + 1;
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return "https://storage.googleapis.com/narrator_audio_files/"
      "google_tts/narrator_${Uri.encodeComponent(nativeLanguage)}/"
      "narrator_greetings_$randomNumber.mp3?timestamp=$timestamp";
}

/// Builds the URL for the audio cue file.
String getAudioCueUrl() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return "https://storage.googleapis.com/narrator_audio_files/"
      "general/audio_cue.mp3?timestamp=$timestamp";
}

/// Builds the URL for the default (conversation) audio files.
String getConversationAudioUrl(String fileName, String documentID) {
  return "https://storage.googleapis.com/conversations_audio_files/"
      "$documentID/$fileName.mp3";
}
