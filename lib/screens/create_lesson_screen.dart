// import math package
import 'dart:math';
import 'package:parakeet/screens/confirm_dialogue_screen.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:parakeet/utils/google_tts_language_codes.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/example_scenarios.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  var topic = '';
  var keywords = '';
  var nativeLanguage = 'English (US)';
  var targetLanguage = 'German';
  var length = '4';
  var languageLevel = 'A1';
  final TextEditingController _controller = TextEditingController();
  final activeCreationAllowed = 4; // change this to allow more users

  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> firstDialogue = {};

  @override
  void initState() {
    super.initState();
    _controller.text = example_scenarios[
        Random().nextInt(example_scenarios.length)]; // Set initial random topic
    topic = _controller.text;
  }

  void _reloadPage() {
    regenerateTopic();
  }

  void regenerateTopic() {
    setState(() {
      _controller.text = example_scenarios[Random()
          .nextInt(example_scenarios.length)]; // Update with new random topic
      topic = _controller.text;
    });
  }

  Future<int> countUsersInActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Assuming there's a specific document ID you're interested in, replace 'your_document_id' with it
    final DocumentReference docRef =
        firestore.collection('active_creation').doc('active_creation');

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('users')) {
          final users = data['users'] as List;
          return users.length; // Number of users in the 'users' key
        }
      }
      return 0; // Return 0 if the document doesn't exist or doesn't contain a 'users' key
    } catch (e) {
      print('Error fetching users from active_creation: $e');
      return -1; // Return -1 or handle the error as appropriate
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title!),
        ),
        body: Center(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: AppConstants.horizontalPadding,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _controller,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      maxLength: 400,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: 'Topic of the lesson',
                          counterText: '',
                          suffix: ElevatedButton(
                              onPressed: regenerateTopic,
                              child: const Text('Suggest topic'))),
                      onChanged: (value) {
                        // You can still handle changes here if needed
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
                        labelText:
                            'Enter words you want to learn in any language (optional)',
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
                      items: <String>['English (US)']
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
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Length of lesson',
                      ),
                      value: int.parse(length),
                      onChanged: (value) {
                        setState(() {
                          length = value.toString();
                        });
                      },
                      items: List<int>.generate(3, (i) => i + 2)
                          .map<DropdownMenuItem<int>>((int value) {
                        const lengthDesciptions = {
                          2: 'Short',
                          3: 'Medium',
                          4: 'Long'
                        };
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(lengthDesciptions[value]!),
                        );
                      }).toList(),
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
                    SizedBox(
                      width: 150,
                      height: 50,
                      child: FloatingActionButton.extended(
                        label: const Text('Create audio lesson'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
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
                            var usersInActiveCreation =
                                await countUsersInActiveCreation();
                            if (usersInActiveCreation != -1 &&
                                usersInActiveCreation > activeCreationAllowed) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Oops, this is embarassing 😅 Too many users are creating lessons right now. Please try again in a moment.'),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                              return;
                            }

                            try {
                              final FirebaseFirestore firestore =
                                  FirebaseFirestore.instance;
                              final DocumentReference docRef = firestore
                                  .collection('chatGPT_responses')
                                  .doc();
                              http.post(
                                Uri.parse(
                                    'https://europe-west1-noble-descent-420612.cloudfunctions.net/first_API_calls'),
                                headers: <String, String>{
                                  'Content-Type':
                                      'application/json; charset=UTF-8',
                                  "Access-Control-Allow-Origin":
                                      "*", // Required for CORS support to work
                                },
                                body: jsonEncode(<String, String>{
                                  "requested_scenario": topic,
                                  "keywords": keywords,
                                  "native_language": nativeLanguage,
                                  "target_language": targetLanguage,
                                  "length": length,
                                  "user_ID": FirebaseAuth
                                      .instance.currentUser!.uid
                                      .toString(),
                                  "language_level": languageLevel,
                                  "document_id": docRef.id,
                                  "tts_provider": "1"
                                }),
                              );
                              int counter = 0;
                              bool docExists = false;
                              while (!docExists && counter < 15) {
                                counter++;
                                await Future.delayed(const Duration(
                                    seconds: 1)); // wait for 1 second
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
                                    ).then((result) {
                                      if (result == 'reload') {
                                        _reloadPage();
                                      }
                                    });
                                    ;
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
                                  content: Text(
                                      'Oops, this is embarassing 😅 Something went wrong! Please try again.'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar:
            const BottomMenuBar(currentRoute: '/create_lesson'));
  }
}
