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
