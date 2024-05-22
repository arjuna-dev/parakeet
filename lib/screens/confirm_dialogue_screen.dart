import 'dart:convert';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class ConfirmDialogue extends StatefulWidget {
  const ConfirmDialogue({
    super.key,
    required this.dialogue,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.length,
  });

  final Map<String, dynamic> dialogue;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final String length;

  @override
  State<ConfirmDialogue> createState() => _ConfirmDialogueState();
}

class _ConfirmDialogueState extends State<ConfirmDialogue> {
  Map<String, dynamic> script = {};
  Map<int, Map<String, bool>> selectedWords = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.dialogue['all_turns']?.length; i++) {
      final turn = widget.dialogue['all_turns'][i];
      final targetLanguageSentence = turn['target_language'] ?? "";
      final words = targetLanguageSentence.split(' ');
      selectedWords[i] = {for (var word in words) word: true};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm dialogue'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Topic'),
                      subtitle: Text(widget.dialogue['title'] ?? "No title"),
                    ),
                    const ListTile(
                      title: Text(
                          'Select words that you want to repeat in your audio'),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.dialogue['all_turns']?.length,
                      itemBuilder: (context, index) {
                        final turn = widget.dialogue['all_turns'][index];
                        final words =
                            (turn['target_language'] ?? "").split(' ');
                        return ListTile(
                          title: Text('Sentence Number: ${turn['turn_nr']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(turn['native_language'] ??
                                  "No native language"),
                              Wrap(
                                children: words.map<Widget>((word) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: selectedWords[index]![word],
                                        onChanged: (bool? value) {
                                          setState(() {
                                            selectedWords[index]![word] =
                                                value!;
                                          });
                                        },
                                      ),
                                      Text(word),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            FloatingActionButton(
              onPressed: () async {
                print("confirmed");
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
                        'https://europe-west1-noble-descent-420612.cloudfunctions.net/full_API_workflow'), // need the function url here
                    headers: <String, String>{
                      'Content-Type': 'application/json; charset=UTF-8',
                      "Access-Control-Allow-Origin":
                          "*", // Required for CORS support to work
                    },
                    body: jsonEncode(<String, dynamic>{
                      "response_db_id": widget.dialogue["response_db_id"],
                      "dialogue": widget.dialogue["all_turns"],
                      "title": widget.dialogue["title"],
                      "speakers": widget.dialogue["speakers"],
                      "user_ID": widget.dialogue["user_ID"],
                      "native_language": widget.nativeLanguage,
                      "target_language": widget.targetLanguage,
                      "length": widget.length,
                      "language_level": widget.languageLevel,
                      "words_to_repeat": selectedWords.entries
                          .expand((entry) => entry.value.entries)
                          .where((innerEntry) => innerEntry.value == true)
                          .map((innerEntry) => innerEntry.key)
                          .toList(),
                    }),
                  );

                  if (response.statusCode == 200) {
                    final Map<String, dynamic> data = jsonDecode(response.body);
                    // await FirebaseFirestore.instance
                    //     .collection('jsonFiles')
                    //     .add(data);
                    print(data);
                    script = data;
                  } else {
                    throw Exception('Failed to load API data');
                  }
                } catch (e) {
                  print("Error: $e");
                } finally {
                  if (script.isNotEmpty && script.containsKey('script')) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => AudioPlayerScreen(
                                script: script['script'],
                                dialogue: widget.dialogue["all_turns"],
                                responseDbId: widget.dialogue["response_db_id"],
                                userID: FirebaseAuth.instance.currentUser!.uid,
                                audioDurations: script['fileDurations'],
                              )),
                    );
                  } else {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Something went wrong! Please try again.'),
                        duration: Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}
