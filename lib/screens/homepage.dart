import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<HomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<HomePage> {
  var topic = '';

  var keywords = '';

  var nativeLanguage = '';

  var learningLanguage = '';

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
              FloatingActionButton(
                onPressed: () async {
                  print('pressed');
                  // try {
                  //   final result = await FirebaseFunctions.instanceFor(
                  //           region: 'us-central1')
                  //       .httpsCallable('chatGPT_API_call_0')
                  //       .call(
                  //     {
                  //       "requested_scenario": topic,
                  //       "keywords": keywords,
                  //       "native_language": nativeLanguage,
                  //       "target_language": learningLanguage,
                  //       "length": "4",
                  //       "user_ID": "1",
                  //       "language_level": "A1",
                  //     },
                  //   );
                  //   print(result.data);
                  // } on FirebaseFunctionsException catch (e) {
                  //   print('Firebase Functions error: ${e.code}\n${e.details}');
                  // } catch (e) {
                  //   print('General error: $e');
                  // }
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
                      "length": "4",
                      "user_ID": "1",
                      "language_level": "A1",
                    }),
                  );
                  if (response.statusCode == 200) {
                    final Map<String, dynamic> data = jsonDecode(response.body);

                    DocumentReference docRef = FirebaseFirestore.instance
                        .collection('chatGPT_responses')
                        .doc();
                    CollectionReference subcollectionRef =
                        docRef.collection('only_target_sentences');
                    await subcollectionRef.add(data);
                    print(data);
                    // IMPORTANT: need to parse docRef.id to the second api to store it in the correct place in the db
                  } else {
                    throw Exception('Failed to load API data');
                  }
                },
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.home),
                onPressed: () {
                  if (ModalRoute.of(context)?.settings.name != '/') {
                    Navigator.pushNamed(context, '/');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  Navigator.pushNamed(context, '/search');
                },
              ),
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/login', (route) => false);
                },
              ),
            ],
          ),
        ));
  }
}
