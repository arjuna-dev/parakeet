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
  var languageLevel = 'Absolute beginner (A1)';
  final TextEditingController _controller = TextEditingController();
  final activeCreationAllowed = 20; // change this to allow more users
  final numberOfAPIcallsAllowed = 5; // change this to allow more API calls

  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> firstDialogue = {};

  @override
  void initState() {
    super.initState();
    _controller.text = example_scenarios[
        Random().nextInt(example_scenarios.length)]; // Set initial random topic
    topic = _controller.text;
    _loadUserPreferences();
  }

  void _loadUserPreferences() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef = firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid);

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('native_language')) {
          setState(() {
            nativeLanguage = data['native_language'];
          });
        }
        if (data.containsKey('target_language')) {
          setState(() {
            targetLanguage = data['target_language'];
          });
        }
        if (data.containsKey('language_level')) {
          setState(() {
            languageLevel = data['language_level'];
          });
        }
      }
    } catch (e) {
      print('Error fetching user preferences: $e');
    }
  }

  Future<void> _saveUserPreferences(String key, String value) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .set({key: value}, SetOptions(merge: true));
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

  Future<int> countAPIcallsByUser() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference userDocRef = firestore
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid.toString())
        .collection('api_call_count')
        .doc('first_API_calls');

    try {
      final DocumentSnapshot doc = await userDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('call_count') &&
            data['last_call_date'] ==
                "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}") {
          return data[
              'call_count']; // Number of api calls made by the user in that day
        }
      }
      return 0; // Return 0 if the document doesn't exist or doesn't contain a 'users' key
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
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
                    Stack(children: [
                      TextFormField(
                        controller: _controller,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        maxLength: 400,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                              vertical: 20.0, horizontal: 10.0),
                          border: OutlineInputBorder(),
                          labelText: 'Topic of the lesson',
                          counterText: '',
                        ),
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
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: GestureDetector(
                          onTap: () {
                            regenerateTopic();
                          },
                          child: RichText(
                            text: const TextSpan(
                                text: 'suggest+',
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: Colors.deepPurple,
                                  fontSize: 16,
                                )),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText:
                            ' (optional) Enter words you want to learn in any language',
                        labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
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
                        _saveUserPreferences(
                            'native_language', value.toString());
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
                        _saveUserPreferences(
                            'target_language', value.toString());
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
                        _saveUserPreferences(
                            'language_level', value.toString());
                      },
                      items: <String>[
                        'Absolute beginner (A1)',
                        'Beginner (A2-B1)',
                        'Intermediate (B2-C1)',
                        'Advanced (C2)'
                      ].map<DropdownMenuItem<String>>((String value) {
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
                                      'Oops, this is embarrassing 😅 Too many users are creating lessons right now. Please try again in a moment.'),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                              return;
                            }
                            var apiCallsByUser = await countAPIcallsByUser();
                            if (apiCallsByUser != -1 &&
                                apiCallsByUser >= numberOfAPIcallsAllowed) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Unfortunately, you have reached the maximum number of creation for today 🙃. Please try again tomorrow.'),
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
                                      'Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
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
