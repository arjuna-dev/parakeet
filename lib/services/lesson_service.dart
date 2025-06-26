import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/activate_free_trial.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/lesson_credit_service.dart';

class LessonService {
  static const int activeCreationAllowed = 20;
  static const int freeAPILimit = 2;
  static const int premiumAPILimit = 10;

  // Function to check credit limits and deduct credit if available
  static Future<bool> checkAndDeductCredit(BuildContext context) async {
    // Try to deduct a credit
    final hasCredit = await LessonCreditService.checkAndDeductCredit();

    if (!hasCredit) {
      // No credits remaining, show dialog
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
      final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

      final shouldEnablePremium = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final colorScheme = Theme.of(context).colorScheme;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainer.withOpacity(0.8),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.shade400,
                            Colors.amber.shade700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Unlock Premium',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'You\'ve used all your credits',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 20),

                    // Features
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Generate up to 100 lessons per month',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                color: colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Access to all categories',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Action Buttons
                    Column(
                      children: [
                        // Primary Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                final success = await activateFreeTrial(context, FirebaseAuth.instance.currentUser!.uid);
                                if (context.mounted) {
                                  Navigator.pop(context, success);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context, false);
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: colorScheme.primary.withOpacity(0.3),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  hasUsedTrial ? 'Get Premium for 1 Month' : 'Try Free for 14 Days',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Secondary Button
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Maybe Later',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // If dialog was dismissed or user chose not to upgrade
      if (shouldEnablePremium != true) {
        return false;
      }
    }

    // Check if there are too many users in active creation
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

    return true;
  }

  // Function to check premium status and API limits
  static Future<bool> checkPremiumAndAPILimits(BuildContext context) async {
    // Check premium status
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
    final isPremium = userDoc.data()?['premium'] ?? false;
    final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

    final apiCalls = await countAPIcallsByUser();
    // Free user limit
    if (!isPremium) {
      if (apiCalls >= freeAPILimit) {
        final shouldEnablePremium = await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            final colorScheme = Theme.of(context).colorScheme;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainer.withOpacity(0.8),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Premium Icon
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.amber.shade700,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      Text(
                        'Unlock Premium',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'You\'ve reached the free limit',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Features
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Generate up to 10 lessons per day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.all_inclusive,
                                  color: colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Access to all categories',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Action Buttons
                      Column(
                        children: [
                          // Primary Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  final success = await activateFreeTrial(context, FirebaseAuth.instance.currentUser!.uid);
                                  if (context.mounted) {
                                    Navigator.pop(context, success);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.pop(context, false);
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor: colorScheme.primary.withOpacity(0.3),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    hasUsedTrial ? 'Get Premium for 1 Month' : 'Try Free for 14 Days',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Secondary Button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              style: TextButton.styleFrom(
                                foregroundColor: colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Maybe Later',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );

        // If dialog was dismissed or user chose not to upgrade
        if (shouldEnablePremium != true) {
          return false;
        }
      }
    } else {
      // Premium user limit
      if (apiCalls >= premiumAPILimit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unfortunately, you have reached the maximum number of creation for today 🙃. Please come back tomorrow.'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
    }

    // Check if there are too many users in active creation
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

  // Function to count API calls by user (keeps for backwards compatibility with call_count tracking)
  static Future<int> countAPIcallsByUser() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference userDocRef = firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid.toString()).collection('api_call_count').doc('first_API_calls');

    try {
      final DocumentSnapshot doc = await userDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Keep showing call_count and last_call_date as is, but don't reset daily
        if (data.containsKey('call_count')) {
          return data['call_count'];
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
      return -1;
    }
  }

  // Function to get current lesson credits
  static Future<int> getCurrentCredits() async {
    return await LessonCreditService.getCurrentCredits();
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

    final canProceed = await checkAndDeductCredit(context);
    if (!canProceed) {
      setIsCreatingCustomLesson(false);
      return;
    }

    // Check if context is still valid after the premium check
    if (!context.mounted) {
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

      // Create an empty script document ID
      DocumentReference scriptDocRef = firestore.collection('chatGPT_responses').doc(documentId).collection('script-$userId').doc();

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

      // Check if context is still valid before navigation
      if (context.mounted) {
        // Navigate directly to AudioPlayerScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AudioPlayerScreen(
              dialogue: const [],
              title: topic,
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
      }
    } catch (e) {
      print(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
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

  // create a function to select 5 words from the category according to certain criteria
  static Future<List<dynamic>> selectWordsFromCategory(String category, List<String> allWords, String targetLanguage) async {
    // check if there are due words in the category stored in the firestore
    final userId = FirebaseAuth.instance.currentUser!.uid.toString();
    final categoryDocs = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(category).collection(category).get();
    // check each word in categoryDocs and see if it is due or overdue
    var words = <String>[];
    final existingWordsCard = <String>[];
    final closestDueDateCard = <Map<String, dynamic>>[];

    for (var doc in categoryDocs.docs) {
      // Handle both string and int formats for date fields
      DateTime dueDate;
      DateTime lastReview;

      final docData = doc.data();
      final dueField = docData['due'];
      if (dueField is String) {
        try {
          dueDate = DateTime.parse(dueField);
        } catch (e) {
          continue; // Skip this document if due date can't be parsed
        }
      } else if (dueField is int) {
        if (dueField == 0) {
          // Handle legacy case where due was set to 0 - treat as far future for mastered words
          dueDate = DateTime.now().add(const Duration(days: 365));
        } else {
          dueDate = DateTime.fromMillisecondsSinceEpoch(dueField);
        }
      } else {
        continue; // Skip this document if due date format is unexpected
      }

      final lastReviewField = docData['lastReview'];
      if (lastReviewField is String) {
        try {
          lastReview = DateTime.parse(lastReviewField);
        } catch (e) {
          continue; // Skip this document if lastReview date can't be parsed
        }
      } else if (lastReviewField is int) {
        lastReview = DateTime.fromMillisecondsSinceEpoch(lastReviewField);
      } else {
        continue; // Skip this document if lastReview format is unexpected
      }

      final daysOverdue = DateTime.now().difference(dueDate).inDays;
      final daysSinceLastReview = DateTime.now().difference(lastReview).inDays;

      // CASE 1: if there are due or overdue words and the word has not been reviewed today, add them to the words list
      final wordField = docData['word'];
      if (wordField == null || wordField is! String) {
        continue; // Skip this document if word field is missing or not a string
      }

      if (daysSinceLastReview > 0) {
        if (daysOverdue <= 0) {
          words.add(wordField);
        } else {
          closestDueDateCard.add({
            'word': wordField,
            'due_date': docData['due'],
            'daysOverdue': daysOverdue,
          });
        }
        print('words: $words');
        print('closestDueDateCard: $closestDueDateCard');
      }
      existingWordsCard.add(wordField);
    }

    if (words.length > 5) {
      words = words.sublist(0, 5);
    }

    if (words.length < 5) {
      // CASE 2: if there are less than 5 words, check if there are any words in allWords that are not in existingWordsCard
      final lowerCaseAllWords = allWords.map((word) => word.toLowerCase()).toList();
      final newWords = lowerCaseAllWords.where((word) => !existingWordsCard.contains(word)).toList();
      // randomize the newWords list
      newWords.shuffle();
      if (newWords.isNotEmpty) {
        final wordsNeeded = 5 - words.length;
        final wordsToAdd = newWords.length >= wordsNeeded ? newWords.sublist(0, wordsNeeded) : newWords;
        words.addAll(wordsToAdd);
      }

      if (words.length < 5) {
        // CASE 3: if there are still less than 5 words, check if there are any words in closestDueDateCard
        if (closestDueDateCard.isNotEmpty) {
          closestDueDateCard.sort((a, b) => a['due_date'].compareTo(b['due_date']));
          final wordsNeeded = 5 - words.length;
          final wordsToAdd = closestDueDateCard.length >= wordsNeeded ? closestDueDateCard.sublist(0, wordsNeeded) : closestDueDateCard;
          words.addAll(wordsToAdd.map((item) => item['word'] as String));
        }
      }
    }
    return words;
  }
}
