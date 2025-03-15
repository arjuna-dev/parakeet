import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
import 'package:parakeet/services/home_screen_service.dart';
import 'package:parakeet/widgets/home_screen/tab_content_view.dart';

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
          Consumer<HomeScreenModel>(
            builder: (context, model, _) {
              return TabContentView(
                isSmallScreen: isSmallScreen,
                child: HomeScreenService.buildNowPlayingList(context, model, _reloadPage),
              );
            },
          ),

          // Favorites Tab
          Consumer<HomeScreenModel>(
            builder: (context, model, _) {
              return TabContentView(
                isSmallScreen: isSmallScreen,
                child: HomeScreenService.buildFavoritesList(context, model, _reloadPage),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/favorite"),
    );
  }
}
