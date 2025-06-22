import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/home_screen.dart';
import 'package:parakeet/screens/create_lesson_screen.dart';
import 'package:parakeet/screens/custom_lesson_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<String> _routes = ['/favorite', '/create_lesson', '/custom_lesson'];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: [
          // Home/Library Screen
          ChangeNotifierProvider(
            create: (context) => HomeScreenModel(),
            child: const Home(),
          ),
          // Create Lesson Screen
          const CreateLesson(title: "Categories"),
          // Custom Lesson Screen
          const CustomLessonScreen(),
        ],
      ),
      bottomNavigationBar: BottomMenuBar(
        currentRoute: _routes[_currentIndex],
        pageController: _pageController,
        onTabTapped: _onTabTapped,
      ),
    );
  }
}
