import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:auralearn/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          FloatingActionButton(
            child: const Text('Logout'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Consumer<HomeScreenModel>(
        // Replace the body with this
        builder: (context, model, child) {
          return ListView.builder(
            itemCount: model.selectedAudioFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.selectedAudioFiles[index];
              return Card(
                  child: ListTile(
                      title: Text(audioFile.get('title')),
                      subtitle: Text(
                          "Learning language: ${audioFile.get('target_language')} \n"
                          "Difficulty: ${audioFile.get('language_level')} level \n"),
                      leading: const Icon(Icons.audio_file),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              script: audioFile.get('script'),
                              responseDbId:
                                  audioFile.reference.parent.parent!.id,
                              dialogue: audioFile.get('dialogue'),
                              audioDurations: audioFile.get('fileDurations'),
                            ),
                          ),
                        );
                      }));
            },
          );
        },
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/"),
    );
  }
}
