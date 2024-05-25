import 'dart:convert';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class ConfirmDialogue extends StatefulWidget {
  const ConfirmDialogue({
    super.key,
    required this.firstDialogue,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.length,
    required this.documentID,
  });

  final Map<String, dynamic> firstDialogue;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final String length;
  final String documentID;

  @override
  State<ConfirmDialogue> createState() => _ConfirmDialogueState();
}

class _ConfirmDialogueState extends State<ConfirmDialogue> {
  Map<String, dynamic> script = {};
  Map<int, Map<String, bool>> selectedWords = {};
  Map<String, dynamic> allDialogue = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm dialogue'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chatGPT_responses')
            .doc(widget.documentID)
            .collection('only_target_sentences')
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Text('Something went wrong');
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          }

          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ListTile(
                    title: const Text('Topic'),
                    subtitle: Text(widget.firstDialogue['title'] ?? "No title"),
                  ),
                  const ListTile(
                    title: Text(
                        'Select words that you want to repeat in your audio:'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Column(
                            children: snapshot.data!.docs
                                .map((DocumentSnapshot document) {
                              allDialogue =
                                  document.data() as Map<String, dynamic>;
                              List<dynamic> turns = [];
                              if (allDialogue.containsKey("all_turns")) {
                                turns = allDialogue["all_turns"];
                              }

                              return ListView.builder(
                                itemBuilder: (context, index) {
                                  if (index >= turns.length) {
                                    return Container(); // Return an empty container if index is out of bounds
                                  }
                                  final turn = turns[index];
                                  final targetLanguageSentence =
                                      turn['target_language'] ?? "";
                                  final words =
                                      targetLanguageSentence?.split(' ');
                                  words.forEach((word) {
                                    if (selectedWords[index] == null) {
                                      selectedWords[index] = {};
                                    }
                                    if (selectedWords[index]![word] == null) {
                                      selectedWords[index]![word] = true;
                                    }
                                  });

                                  return ListTile(
                                    title: Text(
                                        'Sentence Number: ${turn['turn_nr']}'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(turn['native_language'] ??
                                            "No native language"),
                                        Wrap(
                                          children: words.map<Widget>((word) {
                                            return Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Checkbox(
                                                  value: selectedWords[index]![
                                                      word],
                                                  onChanged: (bool? value) {
                                                    setState(() {
                                                      selectedWords[index]![
                                                          word] = value!;
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
                                itemCount: turns.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                              );
                            }).toList(),
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
                            "response_db_id":
                                widget.firstDialogue["response_db_id"],
                            "dialogue": allDialogue["all_turns"],
                            "title": widget.firstDialogue["title"],
                            "speakers": widget.firstDialogue["speakers"],
                            "user_ID": widget.firstDialogue["user_ID"],
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
                          final Map<String, dynamic> data =
                              jsonDecode(response.body);
                          print(data);
                          script = data;

                          if (script.isNotEmpty &&
                              script.containsKey('script')) {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => AudioPlayerScreen(
                                        script: script['script'],
                                        dialogue: allDialogue["all_turns"],
                                        responseDbId: widget
                                            .firstDialogue["response_db_id"],
                                        userID: FirebaseAuth
                                            .instance.currentUser!.uid,
                                        title: script['title'],
                                        audioDurations: script['fileDurations'],
                                      )),
                            );
                          } else {
                            throw Exception(
                                'Proper data not received from API');
                          }
                        } else {
                          throw Exception('Failed to load API data');
                        }
                      } catch (e) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Something went wrong! Please try again.'),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                    child: const Text('Confirm'),
                  )
                ]),
          );
        },
      ),
    );
  }
}
