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
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final padding = isSmallScreen ? 8.0 : 16.0;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          buildProfilePopupMenu(context),
        ],
      ),
      body: Container(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppConstants.horizontalPadding.left,
            vertical: padding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Currently Playing',
                Icons.play_circle_filled,
                isSmallScreen,
                colorScheme,
              ),
              SizedBox(height: padding / 2),
              Expanded(
                flex: 1,
                child: nowPlayingList(),
              ),
              SizedBox(height: padding),
              _buildSectionHeader(
                'Favorite Lessons',
                Icons.favorite,
                isSmallScreen,
                colorScheme,
              ),
              SizedBox(height: padding / 2),
              Expanded(
                flex: 1,
                child: favoriteAudioList(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/favorite"),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isSmallScreen, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 8 : 12,
        horizontal: isSmallScreen ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 20 : 24,
            color: colorScheme.primary,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Consumer<HomeScreenModel> nowPlayingList() {
    return Consumer<HomeScreenModel>(
      builder: (context, model, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.height < 700;

        return model.nowPlayingFiles.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.headphones_outlined,
                      size: isSmallScreen ? 32 : 48,
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start playing audio lessons to see them here! 🎧',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                itemCount: model.nowPlayingFiles.length,
                itemBuilder: (context, index) {
                  final audioFile = model.nowPlayingFiles[index];
                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      title: Text(
                        audioFile.get('title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 15 : 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.translate, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "${(audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)'} → ${audioFile.get('target_language')}",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.stairs, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                "${audioFile.get('language_level')} level",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      leading: Container(
                        width: isSmallScreen ? 40 : 48,
                        height: isSmallScreen ? 40 : 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          index == 0 ? Icons.play_circle : Icons.history,
                          color: colorScheme.primary,
                          size: isSmallScreen ? 24 : 28,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.primary,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              documentID: audioFile.reference.parent.parent!.id,
                              dialogue: audioFile.get('dialogue'),
                              targetLanguage: audioFile.get('target_language'),
                              nativeLanguage: (audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)',
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

  Consumer<HomeScreenModel> favoriteAudioList() {
    return Consumer<HomeScreenModel>(
      builder: (context, model, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.height < 700;

        return model.favoriteAudioFiles.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_outline,
                      size: isSmallScreen ? 32 : 48,
                      color: colorScheme.primary.withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                        children: <TextSpan>[
                          const TextSpan(text: 'Nothing here yet 😅. '),
                          TextSpan(
                            text: 'Go to library',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.pushReplacementNamed(context, '/library');
                              },
                          ),
                          const TextSpan(text: ' to add audio lessons to your favorite list!'),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                itemCount: model.favoriteAudioFiles.length,
                itemBuilder: (context, index) {
                  final audioFile = model.favoriteAudioFiles[index];
                  return Card(
                    elevation: 2,
                    margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 8 : 12,
                      ),
                      title: Text(
                        audioFile.get('title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 15 : 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.translate, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  "${(audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)'} → ${audioFile.get('target_language')}",
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.stairs, size: 16, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                "${audioFile.get('language_level')} level",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      leading: Container(
                        width: isSmallScreen ? 40 : 48,
                        height: isSmallScreen ? 40 : 48,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.favorite,
                          color: colorScheme.primary,
                          size: isSmallScreen ? 24 : 28,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.primary,
                        size: isSmallScreen ? 24 : 28,
                      ),
                      onTap: () async {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AudioPlayerScreen(
                              documentID: audioFile.reference.parent.parent!.id,
                              dialogue: audioFile.get('dialogue'),
                              targetLanguage: audioFile.get('target_language'),
                              nativeLanguage: (audioFile.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? audioFile.get('native_language') : 'English (US)',
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
