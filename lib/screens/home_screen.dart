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

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
    // Load all lessons
    Provider.of<HomeScreenModel>(context, listen: false).loadAllLessons();
  }

  void _reloadPage() {
    // Reload all lessons
    Provider.of<HomeScreenModel>(context, listen: false).loadAllLessons();
  }

  @override
  Widget build(BuildContext context) {
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
