import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/utils/lesson_constants.dart';

class AudioGenerationService {
  final String documentID;
  final String userID;
  final String title;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;
  final String lessonType;
  final String? requestedTopic;

  AudioGenerationService({
    required this.documentID,
    required this.userID,
    required this.title,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
    this.lessonType = 'conversation',
    this.requestedTopic,
  });

  /// Waits for the first dialogue part to appear (15 second timeout)
  Future<Map<String, dynamic>?> waitForFirstDialogue() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int attempts = 0;
    const maxAttempts =
        8; // 8 * 2 seconds = 16 seconds (slightly over 15 for safety)

    while (attempts < maxAttempts) {
      attempts++;

      try {
        // Get the latest dialogue from Firestore
        QuerySnapshot querySnapshot = await firestore
            .collection('chatGPT_responses')
            .doc(documentID)
            .collection('only_target_sentences')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          Map<String, dynamic> data =
              querySnapshot.docs.first.data() as Map<String, dynamic>;

          // Check if dialogue exists and has at least one entry
          if (data.containsKey('dialogue') &&
              data['dialogue'] is List &&
              data['dialogue'].length > 0) {
            List<dynamic> dialogueData = data['dialogue'];

            // Check if the first dialogue entry is valid
            if (dialogueData.isNotEmpty) {
              var firstEntry = dialogueData[0];
              if (firstEntry is Map &&
                  firstEntry.containsKey('target_language') &&
                  firstEntry.containsKey('native_language') &&
                  firstEntry['target_language'] != null &&
                  firstEntry['native_language'] != null) {
                print('First dialogue part found after $attempts attempts');
                return data;
              }
            }
          }
        }

        // Wait before checking again
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error checking first dialogue: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    print('Warning: First dialogue part not found within 15 seconds');
    return null;
  }

  /// Waits for the dialogue to be fully generated
  Future<Map<String, dynamic>?> waitForCompleteDialogue() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    bool isDialogueComplete = false;
    int attempts = 0;
    const maxAttempts =
        60; // Maximum number of attempts (60 * 2 seconds = 2 minutes)
    Map<String, dynamic>? latestSnapshot;

    while (!isDialogueComplete && attempts < maxAttempts) {
      attempts++;

      try {
        // Get the latest dialogue from Firestore
        QuerySnapshot querySnapshot = await firestore
            .collection('chatGPT_responses')
            .doc(documentID)
            .collection('only_target_sentences')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          Map<String, dynamic> data =
              querySnapshot.docs.first.data() as Map<String, dynamic>;

          // Check if dialogue is complete (has the expected number of turns)
          if (data.containsKey('dialogue') &&
              data['dialogue'] is List &&
              data['dialogue'].length > 0) {
            List<dynamic> dialogueData = data['dialogue'];

            // Store the latest snapshot for later use
            latestSnapshot = data;

            // Get the expected length from the lesson configuration
            String expectedLengthStr = data['length'] ?? '0';
            int expectedLength = int.tryParse(expectedLengthStr) ?? 0;

            // If no expected length is found, try to use a default value
            if (expectedLength <= 0) {
              expectedLength = LessonConstants.defaultDialogueTurns;
            }

            // Count only valid dialogue entries (non-empty)
            int validEntriesCount = 0;
            for (var entry in dialogueData) {
              if (entry is Map &&
                  entry.containsKey('target_language') &&
                  entry.containsKey('native_language') &&
                  entry['target_language'] != null &&
                  entry['native_language'] != null) {
                validEntriesCount++;
              }
            }
            // If we have the expected number of valid dialogue turns, we're done
            if (validEntriesCount >= expectedLength && expectedLength > 0) {
              isDialogueComplete = true;
              break;
            }
          }
        }

        // Wait before checking again
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error checking dialogue completion: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (!isDialogueComplete) {
      print('Warning: Dialogue generation timed out after $attempts attempts');
    } else {
      print(
          'Dialogue generation completed successfully after $attempts attempts');
    }

    return latestSnapshot;
  }

  Future<Map<String, dynamic>?> waitForCompleteGrammarLesson() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int attempts = 0;
    const maxAttempts = 60;
    Map<String, dynamic>? latestSnapshot;

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final querySnapshot = await firestore
            .collection('chatGPT_responses')
            .doc(documentID)
            .collection('only_target_sentences')
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data() as Map<String, dynamic>;
          if (data.containsKey('audio_parts') && data['audio_parts'] is List) {
            latestSnapshot = data;
            if (data['part_2_complete'] == true &&
                data.containsKey('timestamp')) {
              break;
            }
          }
        }
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error checking grammar completion: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return latestSnapshot;
  }

  Future<Map<String, dynamic>?> waitForInitialGrammarLessonPlayback() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final completer = Completer<Map<String, dynamic>?>();
    StreamSubscription<DocumentSnapshot>? subscription;

    Future<void> completeWithSnapshot(Map<String, dynamic> data) async {
      final availablePart1Audio = (data['audio_parts'] as List<dynamic>? ?? const [])
          .map((part) => part.toString())
          .where((part) => part.startsWith('grammar_part_1_batch_'))
          .toList()
        ..sort();

      if (data['part_1_complete'] != true || availablePart1Audio.isEmpty) {
        return;
      }

      final merged = Map<String, dynamic>.from(data);
      merged['audio_parts'] = availablePart1Audio;
      merged['title_audio_ready'] = true;
      print(
          'Initial grammar playback data found with ${availablePart1Audio.length} batch(es)');
      if (!completer.isCompleted) {
        completer.complete(merged);
      }
      await subscription?.cancel();
    }

    subscription = firestore
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('only_target_sentences')
        .doc('updatable_json')
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        return;
      }
      try {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        await completeWithSnapshot(data);
      } catch (e) {
        print('Error checking initial grammar playback data: $e');
      }
    });

    try {
      final initialDoc = await firestore
          .collection('chatGPT_responses')
          .doc(documentID)
          .collection('only_target_sentences')
          .doc('updatable_json')
          .get();
      if (initialDoc.exists) {
        final data = initialDoc.data() as Map<String, dynamic>? ?? {};
        await completeWithSnapshot(data);
      }
    } catch (e) {
      print('Error checking initial grammar playback data: $e');
    }

    return completer.future;
  }

  Future<void> makeSecondGrammarApiCall(Map<String, dynamic> data) async {
    final body = jsonEncode(<String, dynamic>{
      "requested_topic": data['requested_topic'] ?? requestedTopic ?? title,
      "title": data['title'] ?? title,
      "segments": data['segments'] ?? const [],
      "speakers": data['speakers'] ?? const {},
      "audio_parts": data['audio_parts'] ?? const [],
      "native_language": nativeLanguage,
      "target_language": targetLanguage,
      "user_ID": userID,
      "document_id": documentID,
      "language_level": languageLevel,
      "length_minutes": data['length_minutes'] ?? "7",
      "tts_provider": "1",
    });

    final candidateUris = <Uri>[
      Uri.parse('http://127.0.0.1:8081'),
      Uri.parse('http://127.0.0.1:8080/second_API_calls_grammar'),
      Uri.parse(
          'https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls_grammar'),
    ];

    Object? lastError;

    for (final uri in candidateUris) {
      try {
        final response = await http.post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            "Access-Control-Allow-Origin": "*",
          },
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('Second grammar API call succeeded via $uri');
          return;
        }

        lastError =
            'HTTP ${response.statusCode} from $uri: ${response.body}';
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
        'Unable to trigger second grammar API call. Last error: $lastError');
  }

  /// Creates the script document in Firestore
  Future<void> saveScriptToFirestore(
      List<dynamic> script,
      List<dynamic> keywordsUsedInDialogue,
      List<dynamic> completeDialogue,
      String category,
      {List<dynamic>? segments,
      List<dynamic>? audioParts,
      int? part1SegmentCount}) async {
    // Save script to Firestore
    DocumentReference docRef = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('script-$userID')
        .doc(scriptDocumentId);

    await docRef.set({
      "script": script,
      "category": category,
      "lesson_type": lessonType,
      "title": title,
      "dialogue": completeDialogue,
      "segments": segments ?? const [],
      "audio_parts": audioParts ?? const [],
      "part_1_segment_count": part1SegmentCount,
      "native_language": nativeLanguage,
      "target_language": targetLanguage,
      "language_level": languageLevel,
      "words_to_repeat": keywordsUsedInDialogue,
      "user_ID": userID,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// Makes the second API call to generate audio
  Future<void> makeSecondApiCall(
      Map<String, dynamic> data, List<dynamic> keywordsUsedInDialogue) async {
    await http.post(
      Uri.parse(
          'https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Access-Control-Allow-Origin": "*",
      },
      body: jsonEncode(<String, dynamic>{
        "document_id": documentID,
        "dialogue": data['dialogue'] ?? [],
        "title": data['title'] ?? title,
        "speakers": data["speakers"] ?? [],
        "user_ID": userID,
        "native_language": nativeLanguage,
        "target_language": targetLanguage,
        "length": (data['dialogue'] as List).length.toString(),
        "language_level": languageLevel,
        "voice_1_id": data["voice_1_id"] ?? "",
        "voice_2_id": data["voice_2_id"] ?? "",
        "tts_provider": targetLanguage == "Azerbaijani" ? "3" : "1",
        "words_to_repeat": keywordsUsedInDialogue,
      }),
    );
  }

  /// Gets the existing big JSON from Firestore
  Future<Map<String, dynamic>?> getExistingBigJson() async {
    final firestore = FirebaseFirestore.instance;
    if (lessonType == 'grammar') {
      final savedScriptDoc = await firestore
          .collection('chatGPT_responses')
          .doc(documentID)
          .collection('script-$userID')
          .doc(scriptDocumentId)
          .get();
      final liveLessonDoc = await firestore
          .collection('chatGPT_responses')
          .doc(documentID)
          .collection('only_target_sentences')
          .doc('updatable_json')
          .get();

      final savedData = savedScriptDoc.exists
          ? savedScriptDoc.data() as Map<String, dynamic>
          : null;
      final liveData = liveLessonDoc.exists
          ? liveLessonDoc.data() as Map<String, dynamic>
          : null;

      if (savedData == null) {
        return liveData;
      }
      if (liveData == null) {
        return savedData;
      }

      final savedAudioParts =
          savedData['audio_parts'] as List<dynamic>? ?? const [];
      final liveAudioParts =
          liveData['audio_parts'] as List<dynamic>? ?? const [];

      if (liveData['part_2_complete'] == true &&
          savedData['part_2_complete'] != true) {
        return liveData;
      }
      if (liveAudioParts.length > savedAudioParts.length) {
        return liveData;
      }
      return savedData;
    }

    final docRef = firestore
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('all_breakdowns')
        .doc('updatable_big_json');
    final doc = await docRef.get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    }

    return null;
  }

  /// Access a nested value in the big JSON using a path
  String accessBigJson(Map<String, dynamic> listWithBigJson, String path) {
    final pattern = RegExp(r'(\D+)|(\d+)');
    final matches = pattern.allMatches(path);

    dynamic currentMap = listWithBigJson;
    for (var match in matches) {
      final key = match.group(0)!;
      final cleanedKey = key.replaceAll(RegExp(r'^_|_$'), '');

      if (int.tryParse(cleanedKey) != null) {
        // If it's a number, parse it as an index
        int index = int.parse(cleanedKey);
        currentMap = currentMap[index];
      } else {
        // If it's not a number, use it as a string key
        currentMap = currentMap[cleanedKey];
      }

      // If at any point currentMap is null, the key path is invalid
      if (currentMap == null) {
        throw Exception("Invalid path: $path");
      }
    }
    return currentMap;
  }

  /// Removes the user from the active creation collection (same logic as [LessonService.releaseActiveCreationSlot]).
  Future<void> removeFromActiveCreation() async {
    await LessonService.releaseActiveCreationSlot(userID, documentID);
  }
}
