import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AudioGenerationService {
  final String documentID;
  final String userID;
  final String title;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final List<dynamic> wordsToRepeat;
  final String scriptDocumentId;

  AudioGenerationService({
    required this.documentID,
    required this.userID,
    required this.title,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.wordsToRepeat,
    required this.scriptDocumentId,
  });

  /// Waits for the dialogue to be fully generated
  Future<Map<String, dynamic>?> waitForCompleteDialogue() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    bool isDialogueComplete = false;
    int attempts = 0;
    const maxAttempts = 60; // Maximum number of attempts (60 * 2 seconds = 2 minutes)
    Map<String, dynamic>? latestSnapshot;

    while (!isDialogueComplete && attempts < maxAttempts) {
      attempts++;

      try {
        // Get the latest dialogue from Firestore
        QuerySnapshot querySnapshot = await firestore.collection('chatGPT_responses').doc(documentID).collection('only_target_sentences').limit(1).get();

        if (querySnapshot.docs.isNotEmpty) {
          Map<String, dynamic> data = querySnapshot.docs.first.data() as Map<String, dynamic>;

          // Check if dialogue is complete (has the expected number of turns)
          if (data.containsKey('dialogue') && data['dialogue'] is List && data['dialogue'].length > 0) {
            List<dynamic> dialogueData = data['dialogue'];

            // Store the latest snapshot for later use
            latestSnapshot = data;

            // Get the expected length from the lesson configuration
            String expectedLengthStr = data['length'] ?? '0';
            int expectedLength = int.tryParse(expectedLengthStr) ?? 0;

            // If no expected length is found, try to use a default value
            if (expectedLength <= 0) {
              expectedLength = 4; // Default expected length
            }

            // Count only valid dialogue entries (non-empty)
            int validEntriesCount = 0;
            for (var entry in dialogueData) {
              if (entry is Map && entry.containsKey('target_language') && entry.containsKey('native_language') && entry['target_language'] != null && entry['native_language'] != null) {
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
      print('Dialogue generation completed successfully after $attempts attempts');
    }

    return latestSnapshot;
  }

  /// Creates the script document in Firestore
  Future<void> saveScriptToFirestore(List<dynamic> script, List<dynamic> keywordsUsedInDialogue, List<dynamic> completeDialogue, String category) async {
    // Save script to Firestore
    DocumentReference docRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentID).collection('script-$userID').doc(scriptDocumentId);

    await docRef.set({
      "script": script,
      "category": category,
      "title": title,
      "dialogue": completeDialogue,
      "native_language": nativeLanguage,
      "target_language": targetLanguage,
      "language_level": languageLevel,
      "words_to_repeat": keywordsUsedInDialogue,
      "user_ID": userID,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  /// Makes the second API call to generate audio
  Future<void> makeSecondApiCall(Map<String, dynamic> data, List<dynamic> keywordsUsedInDialogue) async {
    await http.post(
      // Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'),
      Uri.parse('http://127.0.0.1:8082'),
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

  /// Adds the current user to the active creation collection
  Future<void> addUserToActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');
    await firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      var userData = {"userId": userID, "documentId": documentID, "timestamp": Timestamp.now()};
      if (snapshot.exists) {
        transaction.update(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      } else {
        transaction.set(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      }
    }).catchError((error) {
      print('Failed to add user to active creation: $error');
    });
  }

  /// Gets the existing big JSON from Firestore
  Future<Map<String, dynamic>?> getExistingBigJson() async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('chatGPT_responses').doc(documentID).collection('all_breakdowns').doc('updatable_big_json');
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

  /// Removes the user from the active creation collection
  Future<void> removeFromActiveCreation() async {
    try {
      final firestore = FirebaseFirestore.instance;
      DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');

      await firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
          List<dynamic> users = data['users'] ?? [];

          // Find and remove the current user's entry
          users.removeWhere((user) => user is Map<String, dynamic> && user['userId'] == userID && user['documentId'] == documentID);

          transaction.update(docRef, {'users': users});
        }
      });
    } catch (e) {
      print("Error removing user from active creation: $e");
    }
  }
}
