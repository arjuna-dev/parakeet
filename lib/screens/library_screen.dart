import 'dart:convert';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  //get current user id
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();

    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
  }

  void deleteFromCloudStorage(documentId) {
    http.post(
      Uri.parse(
          'https://europe-west1-noble-descent-420612.cloudfunctions.net/delete_audio_file'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Access-Control-Allow-Origin": "*", // Required for CORS support to work
      },
      body: jsonEncode(<String, String>{
        "document_id": documentId,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: Consumer<HomeScreenModel>(
        builder: (context, model, child) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collectionGroup('script-$userId').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final documents = snapshot.data!.docs;

              return Padding(
                padding: AppConstants.horizontalPadding,
                child: ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    return Card(
                        child: ListTile(
                            title: Text(documents[index].get('title')),
                            subtitle: Text(
                                "Learning language: ${documents[index].get('target_language')} \n"
                                "Difficulty: ${documents[index].get('language_level')} level \n"),
                            trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () async {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('Confirmation'),
                                        content: const Text(
                                            'Are you sure you want to delete this audio?'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                          TextButton(
                                            child: const Text('Delete'),
                                            onPressed: () async {
                                              await _firestore.runTransaction(
                                                (Transaction
                                                    myTransaction) async {
                                                  myTransaction.delete(
                                                      documents[index]
                                                          .reference);
                                                },
                                              );
                                              final user = FirebaseAuth
                                                  .instance.currentUser;
                                              final userDocRef =
                                                  FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(user!.uid);
                                              String parentId = documents[index]
                                                  .reference
                                                  .parent
                                                  .parent!
                                                  .id;
                                              String docId =
                                                  documents[index].reference.id;
                                              if (model.favoriteAudioFileIds
                                                  .any((file) =>
                                                      file['docId'] ==
                                                          documents[index]
                                                              .reference
                                                              .id &&
                                                      file['parentId'] ==
                                                          documents[index]
                                                              .reference
                                                              .parent
                                                              .parent!
                                                              .id)) {
                                                // Remove the audio file from the favorite list
                                                model.removeAudioFile(
                                                    documents[index]);
                                                // Update the Firestore to remove from favorite list
                                                await userDocRef.update({
                                                  'favoriteAudioFiles':
                                                      FieldValue.arrayRemove([
                                                    {
                                                      'parentId': parentId,
                                                      'docId': docId
                                                    }
                                                  ])
                                                });
                                                //Remove from now playing list which is stored in shared preferences
                                                final prefs =
                                                    await SharedPreferences
                                                        .getInstance();
                                                var nowPlayingIds =
                                                    prefs.getStringList(
                                                        'now_playing_${user.uid}')!;
                                                nowPlayingIds.remove(parentId);
                                                await prefs.setStringList(
                                                    'now_playing_${user.uid}',
                                                    nowPlayingIds);
                                              }
                                              // Delete from cloud storage
                                              deleteFromCloudStorage(parentId);

                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }),
                            leading: IconButton(
                              icon: model.favoriteAudioFileIds.any((file) =>
                                      file['docId'] ==
                                          documents[index].reference.id &&
                                      file['parentId'] ==
                                          documents[index]
                                              .reference
                                              .parent
                                              .parent!
                                              .id)
                                  ? const Icon(Icons.favorite)
                                  : const Icon(Icons.favorite_border),
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                final userDocRef = FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user!.uid);
                                String parentId = documents[index]
                                    .reference
                                    .parent
                                    .parent!
                                    .id;
                                String docId = documents[index].reference.id;
                                if (model.favoriteAudioFileIds.any((file) =>
                                    file['docId'] ==
                                        documents[index].reference.id &&
                                    file['parentId'] ==
                                        documents[index]
                                            .reference
                                            .parent
                                            .parent!
                                            .id)) {
                                  // Remove the audio file from the home screen
                                  model.removeAudioFile(documents[index]);

                                  // Remove the audio file from Firestore
                                  await userDocRef.update({
                                    'favoriteAudioFiles':
                                        FieldValue.arrayRemove([
                                      {'parentId': parentId, 'docId': docId}
                                    ])
                                  });
                                } else {
                                  // Add the audio file to the home screen
                                  model.addAudioFile(documents[index]);

                                  // Add the audio file to Firestore
                                  await userDocRef.set({
                                    'favoriteAudioFiles':
                                        FieldValue.arrayUnion([
                                      {'parentId': parentId, 'docId': docId}
                                    ])
                                  }, SetOptions(merge: true));
                                }
                              },
                            ),
                            onTap: () async {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AudioPlayerScreen(
                                    documentID: documents[index]
                                        .reference
                                        .parent
                                        .parent!
                                        .id,
                                    dialogue: documents[index].get('dialogue'),
                                    userID:
                                        FirebaseAuth.instance.currentUser!.uid,
                                    title: documents[index].get('title'),
                                    generating: false,
                                    wordsToRepeat:
                                        documents[index].get('words_to_repeat'),
                                    scriptDocumentId: documents[index].id,
                                  ),
                                ),
                              );
                            }));
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: const BottomMenuBar(
        currentRoute: '/library',
      ),
    );
  }
}
