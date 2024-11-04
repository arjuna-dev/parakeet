import 'package:flutter/gestures.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';

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

    Provider.of<HomeScreenModel>(context, listen: false).loadNowPlayingFromPreference();
  }

  void _reloadPage() {
    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();

    Provider.of<HomeScreenModel>(context, listen: false).loadNowPlayingFromPreference();
    //setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: <Widget>[
          buildProfilePopupMenu(context),
        ],
      ),
      body: Padding(
        padding: AppConstants.horizontalPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Currently playing',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Flexible(
              flex: 1, // Equal flex factor for equal height
              child: nowPlayingList(),
            ),
            const SizedBox(
              height: 10,
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Favorite Audio Lessons', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(
              height: 10,
            ),
            Flexible(
              flex: 1, // Equal flex factor for equal height
              child: favoriteAudioList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/favorite"),
    );
  }

  Consumer<HomeScreenModel> nowPlayingList() {
    return Consumer<HomeScreenModel>(
      // Replace the body with this
      builder: (context, model, child) {
        return model.nowPlayingFiles.isEmpty
            ? const SizedBox(
                height: 150,
                child: Center(child: Text('Start playing audio lessons to see them here! 🎧🎶🎵')),
              )
            : ListView.builder(
                itemCount: model.nowPlayingFiles.length,
                itemBuilder: (context, index) {
                  final audioFile = model.nowPlayingFiles[index];
                  return Card(
                      child: ListTile(
                          title: Text(audioFile.get('title')),
                          subtitle: Text("Learning language: ${audioFile.get('target_language')} \n"
                              "Difficulty: ${audioFile.get('language_level')} level \n"),
                          leading: const Icon(Icons.audio_file, color: const Color.fromARGB(255, 187, 134, 252)),
                          onTap: () async {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioPlayerScreen(
                                  documentID: audioFile.reference.parent.parent!.id,
                                  dialogue: audioFile.get('dialogue'),
                                  targetLanguage: audioFile.get('target_language'),
                                  wordsToRepeat: audioFile.get('words_to_repeat'),
                                  userID: FirebaseAuth.instance.currentUser!.uid,
                                  title: audioFile.get('title'),
                                  scriptDocumentId: audioFile.id,
                                  generating: false,
                                ),
                              ),
                            ).then((result) {
                              if (result == 'reload') {
                                _reloadPage();
                              }
                            });
                          }));
                },
              );
      },
    );
  }

  Consumer<HomeScreenModel> favoriteAudioList() {
    return Consumer<HomeScreenModel>(
      // Replace the body with this
      builder: (context, model, child) {
        return model.favoriteAudioFiles.isEmpty
            ? SizedBox(
                height: 150,
                child: Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black), // Default text style
                      children: <TextSpan>[
                        const TextSpan(text: 'Nothing here yet 😅.'),
                        TextSpan(
                          text: 'Go to library',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ), // Make text blue to indicate it's clickable
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // Navigator code to navigate to LibraryScreen
                              Navigator.pushReplacementNamed(context, '/library');
                            },
                        ),
                        const TextSpan(text: ' to add audio lessons to your favorite list!'),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
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
                      leading: const Icon(Icons.favorite, color: Color.fromARGB(255, 187, 134, 252)),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              documentID: audioFile.reference.parent.parent!.id,
                              dialogue: audioFile.get('dialogue'),
                              targetLanguage: audioFile.get('target_language'),
                              wordsToRepeat: audioFile.get('words_to_repeat'),
                              userID: FirebaseAuth.instance.currentUser!.uid,
                              title: audioFile.get('title'),
                              scriptDocumentId: audioFile.id,
                              generating: false,
                            ),
                          ),
                        ).then((result) {
                          if (result == 'reload') {
                            _reloadPage();
                          }
                        });
                      },
                    ),
                  );
                },
              );
      },
    );
  }
}
