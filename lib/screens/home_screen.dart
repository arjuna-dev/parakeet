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

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);

    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
    Provider.of<HomeScreenModel>(context, listen: false).loadNowPlayingFromPreference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadPage() {
    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
    Provider.of<HomeScreenModel>(context, listen: false).loadNowPlayingFromPreference();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Lessons',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          buildProfilePopupMenu(context),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          indicatorWeight: 3,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          unselectedLabelStyle: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: isSmallScreen ? 14 : 16,
          ),
          tabs: [
            Tab(
              icon: Icon(Icons.play_circle_filled, size: isSmallScreen ? 22 : 24),
              text: 'Currently Playing',
            ),
            Tab(
              icon: Icon(Icons.favorite, size: isSmallScreen ? 22 : 24),
              text: 'Favorites',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Currently Playing Tab
          _buildTabContent(
            context,
            nowPlayingList(),
            Icons.headphones_outlined,
            'Start playing audio lessons to see them here! 🎧',
            null,
          ),

          // Favorites Tab
          _buildTabContent(
            context,
            favoriteAudioList(),
            Icons.favorite_outline,
            'Nothing here yet 😅.',
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
                children: <TextSpan>[
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
          ),
        ],
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/favorite"),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    Widget contentList,
    IconData emptyIcon,
    String emptyText,
    Widget? additionalWidget,
  ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final padding = isSmallScreen ? 8.0 : 16.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.horizontalPadding.left,
        vertical: padding,
      ),
      child: contentList,
    );
  }

  Consumer<HomeScreenModel> nowPlayingList() {
    return Consumer<HomeScreenModel>(
      builder: (context, model, child) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.height < 700;

        return model.nowPlayingFiles.isEmpty
            ? _buildEmptyState(
                context,
                Icons.headphones_outlined,
                'Start playing audio lessons to see them here! 🎧',
                null,
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                itemCount: model.nowPlayingFiles.length,
                itemBuilder: (context, index) {
                  final audioFile = model.nowPlayingFiles[index];
                  return _buildLessonCard(
                    context,
                    audioFile,
                    index == 0 ? Icons.play_circle : Icons.history,
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
            ? _buildEmptyState(
                context,
                Icons.favorite_outline,
                'Nothing here yet 😅.',
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    children: <TextSpan>[
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
              )
            : ListView.builder(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                itemCount: model.favoriteAudioFiles.length,
                itemBuilder: (context, index) {
                  final audioFile = model.favoriteAudioFiles[index];
                  return _buildLessonCard(
                    context,
                    audioFile,
                    Icons.favorite,
                  );
                },
              );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    IconData icon,
    String message,
    Widget? additionalWidget,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 48 : 64,
            color: colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          if (additionalWidget != null) ...[
            const SizedBox(height: 8),
            additionalWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context,
    dynamic audioFile,
    IconData leadingIcon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

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
                  "${audioFile.get('language_level')}",
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
            leadingIcon,
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
                languageLevel: audioFile.get('language_level'),
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
  }
}
