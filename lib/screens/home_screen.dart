import 'package:auralearn/Navigation/bottom_menu_bar.dart';
import 'package:auralearn/screens/audio_player_screen.dart';
import 'package:auralearn/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();

    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();

    Provider.of<HomeScreenModel>(context, listen: false)
        .loadNowPlayingFromPreference();
  }

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
      body: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Now playing',
              style: TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          nowPlayingList(),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Favorite Audio', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(
            height: 10,
          ),
          favoriteAudioList(),
        ],
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/"),
    );
  }

  Consumer<HomeScreenModel> nowPlayingList() {
    return Consumer<HomeScreenModel>(
      // Replace the body with this
      builder: (context, model, child) {
        return Expanded(
          child: ListView.builder(
            itemCount: model.nowPlayingFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.nowPlayingFiles[index];
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
                              userID: FirebaseAuth.instance.currentUser!.uid,
                              title: audioFile.get('title'),
                              audioDurations: audioFile.get('fileDurations'),
                            ),
                          ),
                        );
                      }));
            },
          ),
        );
      },
    );
  }

  Consumer<HomeScreenModel> favoriteAudioList() {
    return Consumer<HomeScreenModel>(
      // Replace the body with this
      builder: (context, model, child) {
        return Expanded(
          child: ListView.builder(
            itemCount: model.favoriteAudioFiles.length,
            itemBuilder: (context, index) {
              final audioFile = model.favoriteAudioFiles[index];
              return Card(
                child: ListTile(
                  title: Text(audioFile.get('title')),
                  subtitle: Text(
                    "Learning language: ${audioFile.get('target_language')} \n"
                    "Difficulty: ${audioFile.get('language_level')} level \n",
                  ),
                  leading: const Icon(Icons.favorite),
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AudioPlayerScreen(
                          script: audioFile.get('script'),
                          responseDbId: audioFile.reference.parent.parent!.id,
                          dialogue: audioFile.get('dialogue'),
                          userID: FirebaseAuth.instance.currentUser!.uid,
                          title: audioFile.get('title'),
                          audioDurations: audioFile.get('fileDurations'),
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
  }
}
