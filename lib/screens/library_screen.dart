import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:auralearn/services/home_screen_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Library extends StatelessWidget {
  Library({super.key});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
                      trailing: IconButton(
                        icon: const Icon(Icons.home),
                        onPressed: () {
                          // Add the audio file to the home screen
                          Provider.of<HomeScreenModel>(context, listen: false)
                              .addAudioFile(documents[index]);
                        },
                      ),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              script: documents[index].get('script'),
                              responseDbId:
                                  documents[index].reference.parent.parent!.id,
                              dialogue: documents[index].get('dialogue'),
                              audioDurations:
                                  documents[index].get('fileDurations'),
                            ),
                          ),
                        );
                      }));
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
