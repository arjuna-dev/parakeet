import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/audio_url_builder.dart';
import 'package:parakeet/utils/script_generator.dart' as script_generator;
import 'package:parakeet/utils/constants.dart';

class PlaylistGenerator {
  final String documentID;
  final String userID;
  final String nativeLanguage;
  final String targetLanguage;
  final bool hasNicknameAudio;
  final bool addressByNickname;
  final List<dynamic> wordsToRepeat;

  late AudioUrlBuilder audioUrlBuilder;

  PlaylistGenerator({
    required this.documentID,
    required this.userID,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.hasNicknameAudio,
    required this.addressByNickname,
    required this.wordsToRepeat,
  }) {
    audioUrlBuilder = AudioUrlBuilder(
      documentID: documentID,
      userID: userID,
      nativeLanguage: nativeLanguage,
      hasNicknameAudio: hasNicknameAudio,
      addressByNickname: addressByNickname,
    );
  }

  /// Generate script from dialogue with repetition mode
  Future<Map<String, dynamic>> generateScriptWithRepetitionMode(Map<String, dynamic> bigJson, List<dynamic> originalDialogue, RepetitionMode repetitionMode, String category) async {
    // Create a ValueNotifier with the repetition mode
    final repetitionModeNotifier = ValueNotifier<RepetitionMode>(repetitionMode);

    if (originalDialogue.isEmpty) {
      print("Error: Original dialogue is empty.");
    }

    // Call the script generator with the ValueNotifier
    final result = await script_generator.parseAndCreateScript(
      bigJson,
      wordsToRepeat,
      originalDialogue,
      repetitionModeNotifier,
      userID,
      documentID,
      targetLanguage,
      nativeLanguage,
      category,
    );

    // Dispose the ValueNotifier
    repetitionModeNotifier.dispose();

    return result;
  }

  /// Filter script to remove files that start with '$'
  List<dynamic> filterScript(List<dynamic> script) {
    return script.where((fileName) => !fileName.startsWith('\$')).toList();
  }

  /// Generate audio sources from script
  Future<List<AudioSource>> generateAudioSources(List<dynamic> script) async {
    List<String> fileUrls = [];
    for (var fileName in script) {
      String url = await audioUrlBuilder.constructUrl(fileName);
      if (url.isNotEmpty) {
        fileUrls.add(url);
      } else {
        print("Empty string URL for $fileName");
      }
    }

    return fileUrls.where((url) => url.isNotEmpty).map((url) => AudioSource.uri(Uri.parse(url))).toList();
  }
}
