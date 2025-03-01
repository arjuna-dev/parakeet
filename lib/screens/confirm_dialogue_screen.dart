import 'dart:convert';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:parakeet/utils/script_generator.dart' as script_generator;
import 'package:parakeet/main.dart';

class ConfirmDialogue extends StatefulWidget {
  const ConfirmDialogue({
    super.key,
    required this.firstDialogue,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.length,
    required this.documentID,
    required this.wordsToLearn,
  });

  final Map<String, dynamic> firstDialogue;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final String length;
  final String documentID;
  final List<String> wordsToLearn;
  @override
  State<ConfirmDialogue> createState() => _ConfirmDialogueState();
}

class TooltipContainerPainter extends CustomPainter {
  final Color backgroundColor;
  final double triangleHeight;

  TooltipContainerPainter({required this.backgroundColor, this.triangleHeight = 10});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = backgroundColor;
    Path path = Path();
    // Draw the rectangle part
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, triangleHeight, size.width, size.height),
      const Radius.circular(10),
    ));
    // Draw the triangle part
    path.moveTo(size.width / 2 - triangleHeight, triangleHeight);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width / 2 + triangleHeight, triangleHeight);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class _ConfirmDialogueState extends State<ConfirmDialogue> {
  List<String> script = [];
  Map<String, dynamic> smallJsonDocument = {};
  ValueNotifier<bool> isConfirmButtonActive = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
  }

  Future<void> addUserToActiveCreation() async {
    String userId = FirebaseAuth.instance.currentUser!.uid;
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');
    await firestore.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(docRef);
      var userData = {"userId": userId, "documentId": widget.documentID, "timestamp": Timestamp.now()};
      if (snapshot.exists) {
        transaction.update(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      } else {
        transaction.set(docRef, {
          "users": FieldValue.arrayUnion([userData]),
        });
      }
    }).catchError((error) {
      print('Failed to add user to active creation: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    TextStyle dialogueTextStyle(bool isHighlighted) {
      return TextStyle(
        fontSize: 17,
        decoration: isHighlighted ? TextDecoration.underline : TextDecoration.none,
        fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
        decorationColor: isHighlighted ? colorScheme.tertiary : null,
        color: isHighlighted ? colorScheme.tertiary : colorScheme.tertiaryFixed,
        decorationThickness: isHighlighted ? 1.0 : null,
      );
    }

    return ResponsiveScreenWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Conversation'),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('only_target_sentences').snapshots(),
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return const Text('Something went wrong');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary));
            }

            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!isConfirmButtonActive.value &&
                    snapshot.data!.docs.isNotEmpty &&
                    (snapshot.data!.docs[0].data() as Map<String, dynamic>).containsKey('dialogue') &&
                    snapshot.data!.docs[0]['dialogue'] != null &&
                    snapshot.data!.docs[0]['dialogue'].length == int.parse(widget.length) &&
                    snapshot.data!.docs[0]['dialogue'][int.parse(widget.length) - 1].isNotEmpty) {
                  isConfirmButtonActive.value = true;
                }
              });
            }

            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                ListTile(
                  title: const Text('Topic'),
                  subtitle: Text(widget.firstDialogue['title'] ?? "No title"),
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
                        'The highlighted words are the ones you will focus on learning.',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Column(
                            children: snapshot.data!.docs.map((DocumentSnapshot document) {
                              smallJsonDocument = document.data() as Map<String, dynamic>;
                              List<dynamic> turns = [];
                              if (smallJsonDocument.containsKey("dialogue")) {
                                turns = smallJsonDocument["dialogue"] ?? [];
                                script = script_generator.createFirstScript(smallJsonDocument["dialogue"] ?? []);
                              }

                              return ListView.builder(
                                itemCount: turns.length,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  if (index >= turns.length) {
                                    return Container();
                                  }
                                  final turn = turns[index];
                                  final targetLanguageSentence = turn['target_language'] ?? "";
                                  final words = targetLanguageSentence.split(' ');
                                  bool isEven = index % 2 == 0;

                                  return Align(
                                    alignment: isEven ? Alignment.centerLeft : Alignment.centerRight,
                                    child: Container(
                                      width: MediaQuery.of(context).size.width * 0.8,
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isEven ? const Color.fromARGB(255, 85, 52, 115) : const Color.fromARGB(255, 62, 59, 124),
                                        borderRadius: BorderRadius.circular(15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colorScheme.shadow.withOpacity(0.6),
                                            spreadRadius: 1,
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              turn['native_language'] ?? "No native language",
                                              style: TextStyle(
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                            Wrap(
                                              children: words.map<Widget>((word) {
                                                final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '');
                                                print(cleanWord);
                                                final isHighlighted = widget.wordsToLearn.contains(cleanWord);
                                                print(isHighlighted);
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
                                                  margin: EdgeInsets.zero,
                                                  child: Text(
                                                    word,
                                                    style: dialogueTextStyle(isHighlighted),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
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
                            label: const Text('Generate Audio'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: isConfirmButtonActive.value ? Theme.of(context).colorScheme.primary : Colors.grey[400],
                            foregroundColor: Colors.white,
                            onPressed: () async {
                              if (isConfirmButtonActive.value) {
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
                                  DocumentReference docRef = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('script-${FirebaseAuth.instance.currentUser!.uid}').doc();
                                  await docRef.set({
                                    "script": script,
                                    "title": smallJsonDocument["title"],
                                    "dialogue": smallJsonDocument["dialogue"],
                                    "native_language": widget.nativeLanguage,
                                    "target_language": widget.targetLanguage,
                                    "language_level": widget.languageLevel,
                                    "words_to_repeat": widget.wordsToLearn,
                                    "user_ID": FirebaseAuth.instance.currentUser!.uid,
                                    "timestamp": FieldValue.serverTimestamp(),
                                  });
                                  String scriptDocumentID = docRef.id;

                                  http.post(
                                    Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/second_API_calls'),
                                    headers: <String, String>{
                                      'Content-Type': 'application/json; charset=UTF-8',
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
                                      "tts_provider": widget.targetLanguage == "Azerbaijani" ? "3" : "1",
                                      "words_to_repeat": widget.wordsToLearn,
                                    }),
                                  );
                                  if (script.isNotEmpty) {
                                    await addUserToActiveCreation();
                                    Navigator.pop(context);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => AudioPlayerScreen(
                                                dialogue: smallJsonDocument["dialogue"],
                                                title: smallJsonDocument["title"],
                                                documentID: widget.documentID,
                                                userID: FirebaseAuth.instance.currentUser!.uid,
                                                scriptDocumentId: scriptDocumentID,
                                                generating: true,
                                                targetLanguage: widget.targetLanguage,
                                                nativeLanguage: widget.nativeLanguage,
                                                wordsToRepeat: widget.wordsToLearn,
                                              )),
                                    );
                                  } else {
                                    throw Exception('Failed to create script!');
                                  }
                                } catch (e) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Something went wrong! Please try again.'),
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            }),
                      );
                    })
              ]),
            );
          },
        ),
      ),
    );
  }
}
