import 'dart:convert';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parakeet/utils/script_generator.dart' as script_generator;
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
  Map<int, Map<String, ValueNotifier<bool>>> selectedWords = {};
  Map<String, dynamic> bigJsonDocument = {};
  ValueNotifier<bool> selectAllNotifier = ValueNotifier<bool>(true);
  ValueNotifier<bool> isConfirmButtonActive = ValueNotifier<bool>(false);

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

          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isConfirmButtonActive.value &&
                  snapshot.data!.docs.isNotEmpty &&
                  (snapshot.data!.docs[0].data() as Map<String, dynamic>)
                      .containsKey('dialogue') &&
                  snapshot.data!.docs[0]['dialogue'] != null &&
                  snapshot.data!.docs[0]['dialogue'].length ==
                      int.parse(widget.length) &&
                  snapshot
                      .data!
                      .docs[0]['dialogue'][int.parse(widget.length) - 1]
                      .isNotEmpty) {
                isConfirmButtonActive.value = true;
              }
            });
          }

          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  ListTile(
                    title: const Text('Topic'),
                    subtitle: Text(widget.firstDialogue['title'] ?? "No title"),
                  ),
                  Align(
                    alignment:
                        Alignment.centerLeft, // Align the card to the left
                    child: Card(
                      elevation: 3.0, // Adjust the elevation as needed
                      // color: Colors.lightGreen[
                      //     100], // Light green background color for the card
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            8.0), // Adjust the border radius as needed
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.all(8.0), // Add padding inside the card
                        child: Text(
                          'Highlight words that you want to focus on learning.',
                          style: TextStyle(
                              fontSize: 16), // Adjust the font size as needed
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: selectAllNotifier,
                    builder: (context, selectAll, child) {
                      return StatefulBuilder(
                        builder: (context, setState) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 2.0), // Add padding if needed
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: selectAll,
                                  onChanged: (bool? value) {
                                    selectAllNotifier.value = value ?? false;
                                    for (var entry in selectedWords.entries) {
                                      for (var wordEntry
                                          in entry.value.entries) {
                                        wordEntry.value.value =
                                            selectAllNotifier.value;
                                      }
                                    }
                                  },
                                ),
                                const Text("Select All Words"),
                              ],
                            ),
                          );
                        },
                      );
                    },
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
                              List<dynamic> turns = [];
                              if (bigJsonDocument.containsKey("dialogue")) {
                                turns = bigJsonDocument["dialogue"] ?? [];
                                script = script_generator.createFirstScript(
                                    bigJsonDocument["dialogue"] ?? []);
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
                                      targetLanguageSentence.split(' ');
                                  if (selectedWords[index] == null) {
                                    selectedWords[index] = {};
                                  }
                                  words.forEach((word) {
                                    if (selectedWords[index]![word] == null) {
                                      selectedWords[index]![word] =
                                          ValueNotifier<bool>(
                                              selectAllNotifier.value);
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
                                            ValueNotifier<bool>
                                                isSelectedNotifier =
                                                selectedWords[index]![word]!;

                                            return ValueListenableBuilder(
                                              valueListenable:
                                                  isSelectedNotifier,
                                              builder: (BuildContext context,
                                                  bool isSelected,
                                                  Widget? child) {
                                                return GestureDetector(
                                                  onTap: () {
                                                    isSelectedNotifier.value =
                                                        !isSelectedNotifier
                                                            .value;
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 2.0,
                                                        vertical: 0.0),
                                                    margin: EdgeInsets.zero,
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? Colors.lightGreen
                                                          : Colors.transparent,
                                                    ),
                                                    child: Text(
                                                      word,
                                                      style: TextStyle(
                                                        fontSize:
                                                            16, // Adjust font size as needed
                                                        decoration: isSelected
                                                            ? TextDecoration
                                                                .underline
                                                            : TextDecoration
                                                                .none,
                                                        decorationColor: isSelected
                                                            ? const Color
                                                                .fromARGB(
                                                                255, 21, 87, 25)
                                                            : null, // Darker green for underline
                                                        color: Colors
                                                            .black, // Adjust text color if needed
                                                        decorationThickness:
                                                            isSelected
                                                                ? 2.0
                                                                : null,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
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
                  ValueListenableBuilder<bool>(
                      valueListenable: isConfirmButtonActive,
                      builder: (context, value, child) {
                        return Container(
                          width: 200,
                          height: 50,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: FloatingActionButton.extended(
                            label: const Text('Confirm and generate audio'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: isConfirmButtonActive.value
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[400],
                            foregroundColor: Colors.white,
                            onPressed: isConfirmButtonActive.value
                                ? () async {
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
                                      DocumentReference docRef = FirebaseFirestore
                                          .instance
                                          .collection('chatGPT_responses')
                                          .doc(widget.documentID)
                                          .collection(
                                              'script-${FirebaseAuth.instance.currentUser!.uid}')
                                          .doc();
                                      await docRef.set({
                                        "script": script,
                                        "title": bigJsonDocument["title"],
                                        "dialogue": bigJsonDocument["dialogue"],
                                        "target_language":
                                            widget.targetLanguage,
                                        "language_level": widget.languageLevel,
                                        "words_to_repeat": selectedWords.entries
                                            .expand(
                                                (entry) => entry.value.entries)
                                            .where((innerEntry) =>
                                                innerEntry.value.value == true)
                                            .map((innerEntry) => innerEntry.key)
                                            .toList(),
                                        "user_ID": FirebaseAuth
                                            .instance.currentUser!.uid
                                      });
                                      String scriptDocumentID = docRef.id;

                                      http.post(
                                        Uri.parse(
                                            'https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'), // need the function url here
                                        headers: <String, String>{
                                          'Content-Type':
                                              'application/json; charset=UTF-8',
                                          "Access-Control-Allow-Origin":
                                              "*", // Required for CORS support to work
                                        },
                                        body: jsonEncode(<String, dynamic>{
                                          "document_id": widget.documentID,
                                          "dialogue":
                                              bigJsonDocument["dialogue"],
                                          "title": bigJsonDocument["title"],
                                          "speakers":
                                              bigJsonDocument["speakers"],
                                          "user_ID": bigJsonDocument["user_ID"],
                                          "native_language":
                                              widget.nativeLanguage,
                                          "target_language":
                                              widget.targetLanguage,
                                          "length": widget.length,
                                          "language_level":
                                              widget.languageLevel,
                                          "voice_1_id":
                                              bigJsonDocument["voice_1_id"],
                                          "voice_2_id":
                                              bigJsonDocument["voice_2_id"],
                                          "tts_provider": "1",
                                          "words_to_repeat": selectedWords
                                              .entries
                                              .expand((entry) =>
                                                  entry.value.entries)
                                              .where((innerEntry) =>
                                                  innerEntry.value.value ==
                                                  true)
                                              .map((innerEntry) =>
                                                  innerEntry.key)
                                              .toList(),
                                        }),
                                      );
                                      if (script.isNotEmpty) {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(context, '/');
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  AudioPlayerScreen(
                                                    dialogue: bigJsonDocument[
                                                        "dialogue"],
                                                    title: bigJsonDocument[
                                                        "title"],
                                                    documentID:
                                                        widget.documentID,
                                                    userID: FirebaseAuth
                                                        .instance
                                                        .currentUser!
                                                        .uid,
                                                    scriptDocumentId:
                                                        scriptDocumentID,
                                                    generating: true,
                                                    wordsToRepeat: selectedWords
                                                        .entries
                                                        .expand((entry) =>
                                                            entry.value.entries)
                                                        .where((innerEntry) =>
                                                            innerEntry
                                                                .value.value ==
                                                            true)
                                                        .map((innerEntry) =>
                                                            innerEntry.key)
                                                        .toList(),
                                                    //audioDurations: script['fileDurations'],
                                                  )),
                                        );
                                      } else {
                                        throw Exception(
                                            'Failed to create script!');
                                      }
                                    } catch (e) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Something went wrong! Please try again.'),
                                          duration: Duration(seconds: 4),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          ),
                        );
                      })
                ]),
          );
        },
      ),
    );
  }
}
