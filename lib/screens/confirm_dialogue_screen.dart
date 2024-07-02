import 'dart:convert';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parakeet/utils/script_generator.dart' as script_generator;

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
  Map<String, ValueNotifier<bool>> selectedWords = {};
  Map<String, dynamic> smallJsonDocument = {};
  ValueNotifier<bool> selectAllNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> isConfirmButtonActive = ValueNotifier<bool>(false);
  bool hasSelectedWord = false;

  void updateHasSelectedWords() {
    hasSelectedWord = selectedWords.values.any((notifier) => notifier.value);
  }

  Future<void> addUserToActiveCreation() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference docRef =
        firestore.collection('active_creation').doc('active_creation');
    await firestore.runTransaction((transaction) async {
      // Attempt to get the document
      DocumentSnapshot snapshot = await transaction.get(docRef);

      // Prepare the user data
      var userData = {
        "userId": userId,
        "documentId": widget.documentID,
        "timestamp": Timestamp.now()
      };

      if (snapshot.exists) {
        // Document exists, add user ID to array
        transaction.update(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      } else {
        // Document does not exist, create it with user ID in array
        transaction.set(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      }
    }).catchError((error) {
      // Handle any errors that occur during the transaction
      print('Failed to add user to active creation: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Conversation'),
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

            // Collect all words from dialogues
            for (var document in snapshot.data!.docs) {
              smallJsonDocument = document.data() as Map<String, dynamic>;
              List<dynamic> turns = smallJsonDocument['dialogue'] ?? [];
              for (var turn in turns) {
                final targetLanguageSentence = turn['target_language'] ?? '';
                final words = targetLanguageSentence
                    .replaceAll(RegExp(r'\p{P}', unicode: true), '')
                    .toLowerCase()
                    .split(' ')
                    .where(
                        (String word) => word.isNotEmpty) // Remove empty words
                    .toSet()
                    .toList();
                for (var word in words) {
                  if (!selectedWords.containsKey(word)) {
                    selectedWords[word] = ValueNotifier<bool>(false);
                  }
                }
              }
              script = script_generator
                  .createFirstScript(smallJsonDocument['dialogue'] ?? []);
            }
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ListTile(
                  title: const Text('Topic'),
                  subtitle: Text(widget.firstDialogue['title'] ?? "No title"),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children:
                          snapshot.data!.docs.map((DocumentSnapshot document) {
                        smallJsonDocument =
                            document.data() as Map<String, dynamic>;
                        List<dynamic> turns =
                            smallJsonDocument['dialogue'] ?? [];
                        return ListView.builder(
                          itemBuilder: (context, index) {
                            if (index >= turns.length) {
                              return Container(); // Return an empty container if index is out of bounds
                            }
                            final turn = turns[index];
                            return ListTile(
                              title: Text('Dialogue ${turn['turn_nr']}:'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(turn['native_language'] ??
                                      "No native language"),
                                  Text(
                                    turn['target_language'] ?? "",
                                    style: const TextStyle(fontSize: 16),
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
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Card(
                    elevation: 3.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        'Select the words that you want to focus on learning.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: selectAllNotifier,
                  builder: (context, selectAll, child) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: selectAll,
                            onChanged: (bool? value) {
                              selectAllNotifier.value = value ?? false;
                              for (var entry in selectedWords.entries) {
                                entry.value.value = selectAllNotifier.value;
                              }
                              updateHasSelectedWords();
                            },
                          ),
                          const Text("Select All Words"),
                        ],
                      ),
                    );
                  },
                ),
                Wrap(
                  children: selectedWords.entries.map<Widget>((entry) {
                    return ValueListenableBuilder(
                      valueListenable: entry.value,
                      builder: (context, isSelected, child) {
                        return GestureDetector(
                          onTap: () {
                            entry.value.value = !entry.value.value;
                            updateHasSelectedWords();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 4.0),
                            margin: const EdgeInsets.all(4.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.lightGreen
                                  : Colors.transparent,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: isSelected
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: isConfirmButtonActive,
                  builder: (context, value, child) {
                    return Container(
                      width: 200,
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: FloatingActionButton.extended(
                        label: const Text('Generate Audio'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: isConfirmButtonActive.value
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[400],
                        foregroundColor: Colors.white,
                        onPressed: () async {
                          if (isConfirmButtonActive.value) {
                            if (!hasSelectedWord) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                        'Please select at least one word to proceed 🧐'),
                                  ),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              return;
                            }

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
                                "title": smallJsonDocument["title"],
                                "dialogue": smallJsonDocument["dialogue"],
                                "target_language": widget.targetLanguage,
                                "language_level": widget.languageLevel,
                                "words_to_repeat": selectedWords.entries
                                    .where((entry) => entry.value.value == true)
                                    .map((entry) => entry.key)
                                    .toList(),
                                "user_ID":
                                    FirebaseAuth.instance.currentUser!.uid,
                                "timestamp": FieldValue.serverTimestamp(),
                              });
                              String scriptDocumentID = docRef.id;

                              http.post(
                                Uri.parse(
                                    'https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'),
                                headers: <String, String>{
                                  'Content-Type':
                                      'application/json; charset=UTF-8',
                                  "Access-Control-Allow-Origin": "*",
                                },
                                body: jsonEncode(<String, dynamic>{
                                  "document_id": widget.documentID,
                                  "dialogue": smallJsonDocument["dialogue"],
                                  "title": smallJsonDocument["title"],
                                  "speakers": smallJsonDocument["speakers"],
                                  "user_ID": smallJsonDocument["user_ID"],
                                  "native_language": widget.nativeLanguage,
                                  "target_language": widget.targetLanguage,
                                  "length": widget.length,
                                  "language_level": widget.languageLevel,
                                  "voice_1_id": smallJsonDocument["voice_1_id"],
                                  "voice_2_id": smallJsonDocument["voice_2_id"],
                                  "tts_provider": "1",
                                  "words_to_repeat": selectedWords.entries
                                      .where(
                                          (entry) => entry.value.value == true)
                                      .map((entry) => entry.key)
                                      .toList(),
                                }),
                              );
                              if (script.isNotEmpty) {
                                await addUserToActiveCreation();
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/');
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudioPlayerScreen(
                                      dialogue: smallJsonDocument["dialogue"],
                                      title: smallJsonDocument["title"],
                                      documentID: widget.documentID,
                                      userID: FirebaseAuth
                                          .instance.currentUser!.uid,
                                      scriptDocumentId: scriptDocumentID,
                                      generating: true,
                                      wordsToRepeat: selectedWords.entries
                                          .where((entry) =>
                                              entry.value.value == true)
                                          .map((entry) => entry.key)
                                          .toList(),
                                    ),
                                  ),
                                );
                              } else {
                                throw Exception('Failed to create script!');
                              }
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Something went wrong! Please try again.'),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
