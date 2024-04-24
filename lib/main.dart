import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parakeet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var topic = '';

  var keywords = '';

  var nativeLanguage = '';

  var learningLanguage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parakeet'),
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
                final response = await http.post(
                  Uri.parse('https://parakeetapi-hma7fmdqza-uc.a.run.app'),
                  headers: <String, String>{
                    'Content-Type': 'application/json; charset=UTF-8',
                  },
                  body: jsonEncode(<String, String>{
                    'topic': topic,
                    'keywords': keywords,
                    'native_language': nativeLanguage,
                    'learning_language': learningLanguage,
                  }),
                );
                if (response.statusCode == 200) {
                  final Map<String, dynamic> data = jsonDecode(response.body);
                  await FirebaseFirestore.instance
                      .collection('jsonFiles')
                      .add(data);
                  print(data);
                } else {
                  throw Exception('Failed to load API data');
                }
              },
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
