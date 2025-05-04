import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/activate_free_trial.dart';
import 'package:parakeet/screens/lesson_detail_screen.dart';
import 'package:parakeet/screens/audio_player_screen.dart';

class LessonService {
  static const int activeCreationAllowed = 20;

  // Function to check premium status and API limits
  static Future<bool> checkPremiumAndAPILimits(BuildContext context) async {
    // Check premium status
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
    final isPremium = userDoc.data()?['premium'] ?? false;
    final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

    if (!isPremium) {
      final apiCalls = await countAPIcallsByUser();
      if (apiCalls >= 5) {
        final shouldEnablePremium = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Generate up to 15 lessons per day'),
              content: const Text('You\'ve reached the free limit. Activate premium mode!!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No, thanks'),
                ),
                TextButton(
                  onPressed: () async {
                    final success = await activateFreeTrial(context, FirebaseAuth.instance.currentUser!.uid);
                    if (success) {
                      Navigator.pop(context, true);
                    } else {
                      Navigator.pop(context, false);
                    }
                  },
                  child: Text(hasUsedTrial ? 'Get premium for 1 month' : 'Try out free for 30 days'),
                ),
              ],
            );
          },
        );

        if (shouldEnablePremium != true) {
          Navigator.pushReplacementNamed(context, '/create_lesson');
          return false;
        }
      }
    }

    var usersInActiveCreation = await countUsersInActiveCreation();
    if (usersInActiveCreation != -1 && usersInActiveCreation > activeCreationAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Too many users are creating lessons right now. Please try again in a moment.'),
          duration: Duration(seconds: 5),
        ),
      );
      return false;
    }

    var apiCallsByUser = await countAPIcallsByUser();
    if (apiCallsByUser != -1 && apiCallsByUser >= getAPICallLimit(isPremium)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPremium ? 'Unfortunately, you have reached the maximum number of creation for today 🙃. Please try again tomorrow.' : 'You\'ve reached the free limit. Upgrade to premium for more lessons!'),
          duration: const Duration(seconds: 5),
        ),
      );
      return false;
    }

    return true;
  }

  // Function to count users in active creation
  static Future<int> countUsersInActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('users')) {
          final users = data['users'] as List;
          return users.length;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching users from active_creation: $e');
      return -1;
    }
  }

  // Function to count API calls by user
  static Future<int> countAPIcallsByUser() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference userDocRef = firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid.toString()).collection('api_call_count').doc('first_API_calls');

    try {
      final DocumentSnapshot doc = await userDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('call_count') && data['last_call_date'] == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}") {
          return data['call_count'];
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
      return -1;
    }
  }

  // Function to get API call limit based on premium status
  static int getAPICallLimit(bool isPremium) {
    return isPremium ? 15 : 5;
  }

  // Function to create a category-based lesson
  static Future<void> createCategoryLesson(
    BuildContext context,
    Map<String, dynamic> category,
    String nativeLanguage,
    String targetLanguage,
    String languageLevel,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final canProceed = await checkPremiumAndAPILimits(context);
    if (!canProceed) {
      Navigator.pop(context); // Close loading dialog
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/generate_lesson_topic'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "category": category['name'],
          "allWords": category['words'],
          "target_language": targetLanguage,
          "native_language": nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        Navigator.pop(context);

        // Reset any static state in LessonDetailScreen before navigation
        LessonDetailScreen.resetStaticState();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LessonDetailScreen(
              category: category['name'] as String,
              allWords: category['words'] as List<String>,
              title: result['title'] as String,
              topic: result['topic'] as String,
              wordsToLearn: (result['words_to_learn'] as List).cast<String>(),
              languageLevel: languageLevel,
              length: '4',
              nativeLanguage: nativeLanguage,
              targetLanguage: targetLanguage,
            ),
          ),
        );
      } else {
        throw Exception('Failed to generate lesson topic');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Function to create a custom lesson
  static Future<void> createCustomLesson(
    BuildContext context,
    String topic,
    List<dynamic> selectedWords,
    String nativeLanguage,
    String targetLanguage,
    String languageLevel,
    Function setIsCreatingCustomLesson,
  ) async {
    // Validate inputs
    if (topic.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic for your lesson'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one word to learn'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setIsCreatingCustomLesson(true);

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

    final canProceed = await checkPremiumAndAPILimits(context);
    if (!canProceed) {
      Navigator.pop(context); // Close loading dialog
      setIsCreatingCustomLesson(false);
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
      final String documentId = docRef.id;
      final String userId = FirebaseAuth.instance.currentUser!.uid.toString();
      final response = await http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/translate_keywords'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "keywords": selectedWords,
          "target_language": targetLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> keywords = data['keywords'].map((word) => word.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').toLowerCase()).toList();
        selectedWords = keywords;
      }

      // Make the API call
      http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/first_API_calls'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "requested_scenario": topic,
          "keywords": selectedWords,
          "native_language": nativeLanguage,
          "target_language": targetLanguage,
          "length": '4',
          "user_ID": userId,
          "language_level": languageLevel,
          "document_id": documentId,
          "tts_provider": targetLanguage == 'Azerbaijani' ? TTSProvider.openAI.value.toString() : TTSProvider.googleTTS.value.toString(),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AudioPlayerScreen(
                  dialogue: firstDialogue["dialogue"] ?? [],
                  title: firstDialogue["title"] ?? topic,
                  documentID: documentId,
                  userID: userId,
                  scriptDocumentId: scriptDocRef.id,
                  generating: true,
                  targetLanguage: targetLanguage,
                  nativeLanguage: nativeLanguage,
                  languageLevel: languageLevel,
                  wordsToRepeat: List<String>.from(selectedWords),
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
      setIsCreatingCustomLesson(false);
    }
  }

  // Function to suggest a random lesson
  static Future<Map<String, dynamic>> suggestRandomLesson(
    String targetLanguage,
    String nativeLanguage,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/suggest_custom_lesson'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "target_language": targetLanguage,
          "native_language": nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get random lesson suggestion');
      }
    } catch (e) {
      throw Exception('Failed to get random suggestion: ${e.toString()}');
    }
  }
}
