// import 'dart:ui';

import 'package:auralearn/screens/confirm_dialogue_screen.dart';
import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:auralearn/utils/google_tts_language_codes.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  var topic = '';

  var keywords = '';

  var nativeLanguage = 'English';

  var targetLanguage = 'German';

  var length = '';
  var languageLevel = 'A1';
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> firstDialogue = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title!),
        ),
        body: Center(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Topic',
                  ),
                  onChanged: (value) {
                    setState(() {
                      topic = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a topic';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Keywords',
                  ),
                  onChanged: (value) {
                    setState(() {
                      keywords = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Native Language',
                  ),
                  value: nativeLanguage,
                  onChanged: (value) {
                    setState(() {
                      nativeLanguage = value.toString();
                    });
                  },
                  items: <String>['English']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Learning Language',
                  ),
                  value: targetLanguage,
                  onChanged: (value) {
                    setState(() {
                      targetLanguage = value.toString();
                    });
                  },
                  items: languageCodes.keys
                      .map<DropdownMenuItem<String>>((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Number of sentences',
                  ),
                  onChanged: (value) {
                    setState(() {
                      length = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter number of sentences';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Language Level',
                  ),
                  value: languageLevel,
                  onChanged: (value) {
                    setState(() {
                      languageLevel = value.toString();
                    });
                  },
                  items: <String>['A1', 'A2', 'B1', 'B2', 'C1', 'C2']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      print("pressed");
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      try {
                        final FirebaseFirestore firestore =
                            FirebaseFirestore.instance;
                        final DocumentReference docRef =
                            firestore.collection('chatGPT_responses').doc();
                        http.post(
                          Uri.parse('http://127.0.0.1:8080'),
                          headers: <String, String>{
                            'Content-Type': 'application/json; charset=UTF-8',
                            "Access-Control-Allow-Origin":
                                "*", // Required for CORS support to work
                          },
                          body: jsonEncode(<String, String>{
                            "requested_scenario": topic,
                            "keywords": keywords,
                            "native_language": nativeLanguage,
                            "target_language": targetLanguage,
                            "length": length,
                            "user_ID": FirebaseAuth.instance.currentUser!.uid
                                .toString(),
                            "language_level": languageLevel,
                            "document_id": docRef.id,
                          }),
                        );
                        int counter = 0;
                        bool docExists = false;
                        while (!docExists && counter < 10) {
                          await Future.delayed(
                              const Duration(seconds: 1)); // wait for 1 second
                          final QuerySnapshot snapshot = await docRef
                              .collection('only_target_sentences')
                              .get();
                          if (snapshot.docs.isNotEmpty) {
                            docExists = true;
                            final Map<String, dynamic> data =
                                snapshot.docs.first.data()
                                    as Map<String, dynamic>;
                            firstDialogue = data;

                            if (firstDialogue.isNotEmpty) {
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
                                      documentID: docRef.id),
                                ),
                              );
                            } else {
                              throw Exception(
                                  'Proper data not received from API');
                            }
                          }
                        }
                        if (!docExists) {
                          throw Exception(
                              'Failed to find the response in firestore within 10 second');
                        }
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Something went wrong! Please try again.'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar:
            const BottomMenuBar(currentRoute: '/create_lesson'));
  }
}
