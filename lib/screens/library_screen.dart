import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:auralearn/services/home_screen_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
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
            stream: _firestore.collectionGroup('scripts').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              final documents = snapshot.data!.docs;

              return ListView.builder(
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  return Card(
                      child: ListTile(
                          title: Text(documents[index].get('title')),
                          subtitle: Text(
                              "Learning language: ${documents[index].get('target_language')} \n"
                              "Difficulty: ${documents[index].get('language_level')} level \n"),
                          leading: const Icon(Icons.audio_file),
                          trailing: ValueListenableBuilder(
                              valueListenable:
                                  model.favoriteAudioFileIdsNotifier,
                              builder: (context,
                                  List<dynamic> favoriteAudioFileIds, child) {
                                return IconButton(
                                  icon: model.favoriteAudioFileIds.any((file) =>
                                          file['docId'] ==
                                              documents[index].reference.id &&
                                          file['parentId'] ==
                                              documents[index]
                                                  .reference
                                                  .parent
                                                  .parent!
                                                  .id)
                                      ? const Icon(Icons.star)
                                      : const Icon(Icons.star_border),
                                  onPressed: () async {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    final userDocRef = FirebaseFirestore
                                        .instance
                                        .collection('users')
                                        .doc(user!.uid);
                                    String parentId = documents[index]
                                        .reference
                                        .parent
                                        .parent!
                                        .id;
                                    String docId =
                                        documents[index].reference.id;
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
                                        'selectedAudioFiles':
                                            FieldValue.arrayRemove([
                                          {'parentId': parentId, 'docId': docId}
                                        ])
                                      });
                                    } else {
                                      // Add the audio file to the home screen
                                      model.addAudioFile(documents[index]);

                                      // Add the audio file to Firestore
                                      await userDocRef.set({
                                        'selectedAudioFiles':
                                            FieldValue.arrayUnion([
                                          {'parentId': parentId, 'docId': docId}
                                        ])
                                      }, SetOptions(merge: true));
                                    }
                                  },
                                );
                              }),
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioPlayerScreen(
                                  script: documents[index].get('script'),
                                  responseDbId: documents[index]
                                      .reference
                                      .parent
                                      .parent!
                                      .id,
                                  dialogue: documents[index].get('dialogue'),
                                  userID:
                                      FirebaseAuth.instance.currentUser!.uid,
                                  audioDurations:
                                      documents[index].get('fileDurations'),
                                ),
                              ),
                            );
                          }));
                },
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
