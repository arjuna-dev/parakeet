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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key, this.title});

  final title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Demo'),
        ),
        body: Center(
            child: FloatingActionButton(
          onPressed: () async {
            final response = await http.post(
              Uri.parse('https://parakeetapi-hma7fmdqza-uc.a.run.app'),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
              },
              body: jsonEncode(<String, String>{
                'topic': 'Ordering a coffee',
                'keywords': 'coffee, order, drink',
                'native_language': 'English',
                'learning_language': 'Spanish',
              }),
            );

            if (response.statusCode == 200) {
              // If the server returns a 200 OK response,
              // then parse the JSON.
              final Map<String, dynamic> data = jsonDecode(response.body);

              await FirebaseFirestore.instance
                  .collection('jsonFiles')
                  .add(data);
              print(data);
            } else {
              // If the server returns an unexpected response,
              // then throw an exception.
              throw Exception('Failed to load API data');
            }
          },
          child: const Icon(Icons.add),
        )));
  }
}
