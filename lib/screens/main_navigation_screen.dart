import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/home_screen.dart';
import 'package:parakeet/screens/create_lesson_screen.dart';
import 'package:parakeet/screens/custom_lesson_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/services/loading_state_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final String initialRoute;

  const MainNavigationScreen({
    super.key,
    this.initialRoute = '/custom_lesson',
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late String _currentRoute;

  @override
  void initState() {
    super.initState();
    _currentRoute = widget.initialRoute;
  }

  Widget _getCurrentScreen() {
    switch (_currentRoute) {
      case '/favorite':
        return ChangeNotifierProvider(
          create: (context) => HomeScreenModel(),
          child: const Home(),
        );
      case '/create_lesson':
        return const CreateLesson(title: "Categories");
      case '/custom_lesson':
        return const CustomLessonScreen();
      default:
        return ChangeNotifierProvider(
          create: (context) => HomeScreenModel(),
          child: const Home(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoadingStateService(),
      child: Consumer<LoadingStateService>(
        builder: (context, loadingState, child) {
          return AbsorbPointer(
            absorbing: loadingState.isGeneratingLesson,
            child: Scaffold(
              body: _getCurrentScreen(),
              bottomNavigationBar: BottomMenuBar(
                currentRoute: _currentRoute,
              ),
            ),
          );
        },
      ),
    );
  }
}
