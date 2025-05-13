import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/lesson_service.dart';

class LessonDetailService {
  // Function to regenerate a lesson
  static Future<Map<String, dynamic>?> regenerateLesson({
    required BuildContext context,
    required String category,
    required List<String> allWords,
    required String targetLanguage,
    required String nativeLanguage,
  }) async {
    try {
      // Make the API call to generate a new lesson topic
      final selectedWords = await LessonService.selectWordsFromCategory(category, allWords, targetLanguage);
      final response = await http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/generate_lesson_topic'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "category": category,
          "selectedWords": selectedWords,
          "target_language": targetLanguage,
          "native_language": nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to generate new lesson topic');
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
      return null;
    }
  }

  // Function to start a lesson
  static Future<void> startLesson({
    required BuildContext context,
    required String topic,
    required List<dynamic> wordsToLearn,
    required String nativeLanguage,
    required String targetLanguage,
    required String languageLevel,
    required String length,
    required String category,
    required String title,
    required Function(bool) setIsGeneratingLesson,
  }) async {
    if (wordsToLearn.isEmpty) return;

    final canProceed = await LessonService.checkPremiumAndAPILimits(context);
    if (!canProceed) {
      Navigator.pop(context); // Close loading dialog
      return;
    }

    setIsGeneratingLesson(true);

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
      final String documentId = docRef.id;
      final String userId = FirebaseAuth.instance.currentUser!.uid.toString();
      final TTSProvider ttsProvider = targetLanguage == 'Azerbaijani' ? TTSProvider.openAI : TTSProvider.googleTTS;

      // Make the first API call
      http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/first_API_calls'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "requested_scenario": topic,
          "category": category,
          "keywords": wordsToLearn,
          "native_language": nativeLanguage,
          "target_language": targetLanguage,
          "length": length,
          "user_ID": userId,
          "language_level": languageLevel,
          "document_id": documentId,
          "tts_provider": ttsProvider.value.toString(),
        }),
      );

      int counter = 0;
      bool docExists = false;
      Map<String, dynamic> firstDialogue = {};

      while (!docExists && counter < 15) {
        counter++;
        await Future.delayed(const Duration(seconds: 1));
        final QuerySnapshot snapshot = await docRef.collection('only_target_sentences').get();
        if (snapshot.docs.isNotEmpty) {
          docExists = true;
          final Map<String, dynamic> data = snapshot.docs.first.data() as Map<String, dynamic>;
          firstDialogue = data;

          if (firstDialogue.isNotEmpty) {
            // Create an empty script document ID
            DocumentReference scriptDocRef = firestore.collection('chatGPT_responses').doc(documentId).collection('script-$userId').doc();

            // Navigate directly to AudioPlayerScreen
            Navigator.pop(context); // Close loading dialog
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AudioPlayerScreen(
                  category: category,
                  dialogue: firstDialogue["dialogue"] ?? [],
                  title: title,
                  documentID: documentId,
                  userID: userId,
                  scriptDocumentId: scriptDocRef.id,
                  generating: true,
                  targetLanguage: targetLanguage,
                  nativeLanguage: nativeLanguage,
                  languageLevel: languageLevel,
                  wordsToRepeat: wordsToLearn,
                  numberOfTurns: 4,
                ),
              ),
            );
          } else {
            throw Exception('Proper data not received from API');
          }
        }
      }

      if (!docExists) {
        throw Exception('Failed to find the response in firestore within 15 seconds');
      }
    } catch (e) {
      print(e);
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setIsGeneratingLesson(false);
    }
  }
}
