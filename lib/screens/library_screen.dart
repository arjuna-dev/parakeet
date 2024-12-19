import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
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
      Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/delete_audio_file'),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: <Widget>[
          buildProfilePopupMenu(context),
        ],
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
              documents.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

              return Padding(
                padding: AppConstants.horizontalPadding,
                child: documents.isEmpty
                    ? SizedBox(
                        height: 150,
                        child: Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(color: colorScheme.onPrimaryContainer), // Default text style
                              children: <TextSpan>[
                                const TextSpan(text: 'Your library is empty. '),
                                TextSpan(
                                  text: 'Create your first lesson 🎵',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ), // Make text blue to indicate it's clickable
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      // Navigator code to navigate to LibraryScreen
                                      Navigator.pushReplacementNamed(context, '/create_lesson');
                                    },
                                ),
                                const TextSpan(text: ' to fill it with your audio lessons!'),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (context, index) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: ListTile(
                              title: Text(
                                documents[index].get('title'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.translate, size: 15, color: colorScheme.primary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "${(documents[index].data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? documents[index].get('native_language') : 'English (US)'} → ${documents[index].get('target_language')}",
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.stairs, size: 15, color: colorScheme.primary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                "${documents[index].get('language_level')} level",
                                                style: const TextStyle(fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: IconButton(
                                  icon: model.favoriteAudioFileIds.any((file) => file['docId'] == documents[index].reference.id && file['parentId'] == documents[index].reference.parent.parent!.id)
                                      ? Icon(Icons.favorite, color: colorScheme.primary)
                                      : Icon(Icons.favorite_border, color: colorScheme.primary),
                                  onPressed: () async {
                                    final user = FirebaseAuth.instance.currentUser;
                                    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                                    String parentId = documents[index].reference.parent.parent!.id;
                                    String docId = documents[index].reference.id;
                                    if (model.favoriteAudioFileIds.any((file) => file['docId'] == documents[index].reference.id && file['parentId'] == documents[index].reference.parent.parent!.id)) {
                                      model.removeAudioFile(documents[index]);
                                      await userDocRef.update({
                                        'favoriteAudioFiles': FieldValue.arrayRemove([
                                          {'parentId': parentId, 'docId': docId}
                                        ])
                                      });
                                    } else {
                                      model.addAudioFile(documents[index]);
                                      await userDocRef.set({
                                        'favoriteAudioFiles': FieldValue.arrayUnion([
                                          {'parentId': parentId, 'docId': docId}
                                        ])
                                      }, SetOptions(merge: true));
                                    }
                                  },
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () async {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text('Confirmation'),
                                            content: const Text('Are you sure you want to delete this audio?'),
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
                                                    (Transaction myTransaction) async {
                                                      myTransaction.delete(documents[index].reference);
                                                    },
                                                  );
                                                  final user = FirebaseAuth.instance.currentUser;
                                                  final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                                                  String parentId = documents[index].reference.parent.parent!.id;
                                                  String docId = documents[index].reference.id;
                                                  if (model.favoriteAudioFileIds.any((file) => file['docId'] == documents[index].reference.id && file['parentId'] == documents[index].reference.parent.parent!.id)) {
                                                    // Remove the audio file from the favorite list
                                                    model.removeAudioFile(documents[index]);
                                                    // Update the Firestore to remove from favorite list
                                                    await userDocRef.update({
                                                      'favoriteAudioFiles': FieldValue.arrayRemove([
                                                        {'parentId': parentId, 'docId': docId}
                                                      ])
                                                    });
                                                  }
                                                  //Remove from now playing list which is stored in shared preferences
                                                  final prefs = await SharedPreferences.getInstance();
                                                  await prefs.remove('savedPosition_${parentId}_$userId');
                                                  await prefs.remove('savedTrackIndex_${parentId}_$userId');
                                                  await prefs.remove("now_playing_${parentId}_$userId");
                                                  // Retrieve the now playing list
                                                  List<String>? nowPlayingList = prefs.getStringList("now_playing_$userId");

                                                  // Check if the list is not null
                                                  if (nowPlayingList != null) {
                                                    // Remove widget.documentID from the list if it exists
                                                    nowPlayingList.remove(parentId);

                                                    // Save the updated list back to preferences
                                                    await prefs.setStringList("now_playing_$userId", nowPlayingList);
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
                                    },
                                  ),
                                  Icon(Icons.chevron_right, color: colorScheme.primary),
                                ],
                              ),
                              onTap: () async {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudioPlayerScreen(
                                      documentID: documents[index].reference.parent.parent!.id,
                                      dialogue: documents[index].get('dialogue'),
                                      targetLanguage: documents[index].get('target_language'),
                                      nativeLanguage: (documents[index].data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? documents[index].get('native_language') : 'English (US)',
                                      userID: FirebaseAuth.instance.currentUser!.uid,
                                      title: documents[index].get('title'),
                                      generating: false,
                                      wordsToRepeat: documents[index].get('words_to_repeat'),
                                      scriptDocumentId: documents[index].id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
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
