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
  final String languageLevel;
  final bool hasNicknameAudio;
  final bool addressByNickname;
  final List<dynamic> wordsToRepeat;

  late AudioUrlBuilder audioUrlBuilder;

  PlaylistGenerator({
    required this.documentID,
    required this.userID,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
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
      languageLevel: languageLevel,
    );

    // Dispose the ValueNotifier
    repetitionModeNotifier.dispose();

    return result;
  }

  /// Filter script to remove files that start with '$'
  List<dynamic> filterScript(List<dynamic> script) {
    return script.where((fileName) => !fileName.startsWith('\$')).toList();
  }

  /// Script entries that actually get a playlist item ([generateAudioSources] skips empty URLs).
  /// Track durations must use this list so indices match [ConcatenatingAudioSource] children.
  Future<List<dynamic>> resolveScriptEntriesWithUrls(List<dynamic> script) async {
    final List<dynamic> out = [];
    for (var fileName in script) {
      final String url = await audioUrlBuilder.constructUrl(fileName);
      if (url.isNotEmpty) {
        out.add(fileName);
      } else {
        print("Empty string URL for $fileName");
      }
    }
    return out;
  }

  /// Build sources and the resolved script in one pass (single URL resolution per file).
  Future<({List<AudioSource> sources, List<dynamic> resolvedScript})>
      buildAudioSourcesFromScript(List<dynamic> script) async {
    final List<AudioSource> sources = [];
    final List<dynamic> resolvedScript = [];
    for (var fileName in script) {
      final String url = await audioUrlBuilder.constructUrl(fileName);
      if (url.isNotEmpty) {
        resolvedScript.add(fileName);
        sources.add(AudioSource.uri(Uri.parse(url)));
      } else {
        print("Empty string URL for $fileName");
      }
    }
    return (sources: sources, resolvedScript: resolvedScript);
  }

  Future<List<AudioSource>> audioSourcesForNames(List<dynamic> names) async {
    final List<AudioSource> sources = [];
    for (var fileName in names) {
      final String url = await audioUrlBuilder.constructUrl(fileName);
      if (url.isNotEmpty) {
        sources.add(AudioSource.uri(Uri.parse(url)));
      }
    }
    return sources;
  }

  /// Generate audio sources from script
  Future<List<AudioSource>> generateAudioSources(List<dynamic> script) async {
    final r = await buildAudioSourcesFromScript(script);
    return r.sources;
  }
}
