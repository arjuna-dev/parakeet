import 'package:auralearn/screens/confirm_script_screen.dart';
import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  var topic = '';

  var keywords = '';

  var nativeLanguage = '';

  var learningLanguage = '';

  var length = '';
  var languageLevel = 'A1';

  Map<String, dynamic> script = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title!),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Topic',
                ),
                onChanged: (value) {
                  setState(() {
                    topic = value;
                  });
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
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Native Language',
                ),
                onChanged: (value) {
                  setState(() {
                    nativeLanguage = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Learning Language',
                ),
                onChanged: (value) {
                  setState(() {
                    learningLanguage = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Number of sentences',
                ),
                onChanged: (value) {
                  setState(() {
                    length = value;
                  });
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
                    final response = await http.post(
                      Uri.parse(
                          'https://us-central1-noble-descent-420612.cloudfunctions.net/chatGPT_API_call_0'),
                      headers: <String, String>{
                        'Content-Type': 'application/json; charset=UTF-8',
                        "Access-Control-Allow-Origin":
                            "*", // Required for CORS support to work
                      },
                      body: jsonEncode(<String, String>{
                        "requested_scenario": topic,
                        "keywords": keywords,
                        "native_language": nativeLanguage,
                        "target_language": learningLanguage,
                        "length": length,
                        "user_ID":
                            FirebaseAuth.instance.currentUser!.uid.toString(),
                        "language_level": languageLevel,
                      }),
                    );

                    if (response.statusCode == 200) {
                      final Map<String, dynamic> data =
                          jsonDecode(response.body);
                      await FirebaseFirestore.instance
                          .collection('jsonFiles')
                          .add(data);
                      print(data);
                      script = data;
                    } else {
                      throw Exception('Failed to load API data');
                    }
                  } catch (e) {
                    print('Error: $e');
                  } finally {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfirmScript(script: script),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomMenuBar());
  }
}
