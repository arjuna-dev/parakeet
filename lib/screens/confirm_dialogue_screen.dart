import 'dart:convert';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:auralearn/utils/script_generator.dart' as script_generator;
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
  List<String> script = [];
  Map<int, Map<String, bool>> selectedWords = {};
  Map<String, dynamic> bigJsonDocument = {};

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
                              bigJsonDocument =
                                  document.data() as Map<String, dynamic>;
                              print(bigJsonDocument);
                              List<dynamic> turns = [];
                              if (bigJsonDocument.containsKey("dialogue")) {
                                turns = bigJsonDocument["dialogue"];
                              }
                              print(turns);
                              script = script_generator.createFirstScript(
                                  bigJsonDocument); // need to import script_generator.dart
                              print(script);

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
                        DocumentReference docRef = FirebaseFirestore.instance
                            .collection('chatGPT_responses')
                            .doc(widget.documentID)
                            .collection('script')
                            .doc();
                        await docRef.set({"script": script});
                        String scriptDocumentID = docRef.id;

                        http.post(
                          Uri.parse(
                              'https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'), // need the function url here
                          headers: <String, String>{
                            'Content-Type': 'application/json; charset=UTF-8',
                            "Access-Control-Allow-Origin":
                                "*", // Required for CORS support to work
                          },
                          body: jsonEncode(<String, dynamic>{
                            "document_id": widget.documentID,
                            "dialogue": bigJsonDocument["dialogue"],
                            "title": bigJsonDocument["title"],
                            "speakers": bigJsonDocument["speakers"],
                            "user_ID": bigJsonDocument["user_ID"],
                            "native_language": widget.nativeLanguage,
                            "target_language": widget.targetLanguage,
                            "length": widget.length,
                            "language_level": widget.languageLevel,
                            "voice_1_id": bigJsonDocument["voice_1_id"],
                            "voice_2_id": bigJsonDocument["voice_2_id"],
                            "tts_provider": "1",
                            "words_to_repeat": selectedWords.entries
                                .expand((entry) => entry.value.entries)
                                .where((innerEntry) => innerEntry.value == true)
                                .map((innerEntry) => innerEntry.key)
                                .toList(),
                          }),
                        );
                        if (script.isNotEmpty) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => AudioPlayerScreen(
                                      script: script,
                                      dialogue: bigJsonDocument["dialogue"],
                                      documentID: widget.documentID,
                                      userID: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      title: bigJsonDocument['title'],
                                      scriptDocumentId: scriptDocumentID,
                                      wordsToRepeat: selectedWords.entries
                                          .expand(
                                              (entry) => entry.value.entries)
                                          .where((innerEntry) =>
                                              innerEntry.value == true)
                                          .map((innerEntry) => innerEntry.key)
                                          .toList(),
                                      //audioDurations: script['fileDurations'],
                                    )),
                          );
                        } else {
                          throw Exception('Failed to create script!');
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
