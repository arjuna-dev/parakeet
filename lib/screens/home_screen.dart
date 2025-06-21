import 'package:flutter/material.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/home_screen_service.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';

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
    _tabController = TabController(length: 1, vsync: this);

    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
    Provider.of<HomeScreenModel>(context, listen: false).loadAllLessons();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _reloadPage() {
    // Load the audio files
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
    Provider.of<HomeScreenModel>(context, listen: false).loadAllLessons();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AppBarWithDrawer(
        title: 'All Lessons',
      ),
      body: Consumer<HomeScreenModel>(
        builder: (context, model, _) {
          return HomeScreenService.buildAllLessonsList(context, model, _reloadPage);
        },
      ),
    );
  }
}
