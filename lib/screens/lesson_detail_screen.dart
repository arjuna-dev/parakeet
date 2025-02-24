import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/main.dart';
import 'package:parakeet/screens/confirm_dialogue_screen.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:parakeet/utils/constants.dart';

class LessonDetailScreen extends StatelessWidget {
  final String title;
  final String topic;
  final List<String> wordsToLearn;
  final String languageLevel;
  final String length;
  final String nativeLanguage;
  final String targetLanguage;

  const LessonDetailScreen({
    Key? key,
    required this.title,
    required this.topic,
    required this.wordsToLearn,
    required this.languageLevel,
    required this.length,
    required this.nativeLanguage,
    required this.targetLanguage,
  }) : super(key: key);

  void _handleBack(BuildContext context) {
    Navigator.pushReplacementNamed(context, '/create_lesson');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    var firstDialogue = <String, dynamic>{};
    var ttsProvider = TTSProvider.googleTTS;
    if (targetLanguage == 'Azerbaijani') {
      ttsProvider = TTSProvider.openAI;
    }

    return ResponsiveScreenWrapper(
        child: PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        _handleBack(context);
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(isSmallScreen || kIsWeb ? 48.0 : 56.0),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Lesson Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen || kIsWeb ? 18 : 20,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _handleBack(context),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isSmallScreen ? 8 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Topic Section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                height: isSmallScreen ? 120 : 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Topic',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          topic,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Words to Repeat Section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Words to learn',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: wordsToLearn
                          .map((word) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  word,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: isSmallScreen ? 14 : 16,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Lesson Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        final FirebaseFirestore firestore = FirebaseFirestore.instance;
                        final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
                        http.post(
                          Uri.parse('http://192.168.2.105:8081'),
                          headers: <String, String>{
                            'Content-Type': 'application/json; charset=UTF-8',
                            "Access-Control-Allow-Origin": "*",
                          },
                          body: jsonEncode(<String, dynamic>{
                            "requested_scenario": topic,
                            "keywords": wordsToLearn,
                            "native_language": nativeLanguage,
                            "target_language": targetLanguage,
                            "length": length,
                            "user_ID": FirebaseAuth.instance.currentUser!.uid.toString(),
                            "language_level": languageLevel,
                            "document_id": docRef.id,
                            "tts_provider": ttsProvider.value.toString(),
                          }),
                        );

                        int counter = 0;
                        bool docExists = false;
                        while (!docExists && counter < 15) {
                          counter++;
                          await Future.delayed(const Duration(seconds: 1));
                          final QuerySnapshot snapshot = await docRef.collection('only_target_sentences').get();
                          if (snapshot.docs.isNotEmpty) {
                            docExists = true;
                            final Map<String, dynamic> data = snapshot.docs.first.data() as Map<String, dynamic>;
                            firstDialogue = data;

                            if (firstDialogue.isNotEmpty) {
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ConfirmDialogue(
                                    firstDialogue: firstDialogue,
                                    nativeLanguage: nativeLanguage,
                                    targetLanguage: targetLanguage,
                                    languageLevel: languageLevel,
                                    length: length,
                                    documentID: docRef.id,
                                    wordsToLearn: wordsToLearn,
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
                      } on Exception catch (e) {
                        print(e);
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Start Lesson',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
      ),
    ));
  }
}
