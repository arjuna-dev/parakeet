import 'package:flutter/material.dart';
import 'package:parakeet/utils/constants.dart';

class BottomMenuBar extends StatelessWidget {
  final String currentRoute;

  const BottomMenuBar({
    super.key,
    required this.currentRoute,
  });

  int _getCurrentIndex() {
    switch (currentRoute) {
      case '/favorite':
        return 0;
      case '/create_lesson':
        return 1;
      case '/custom_lesson':
        return 2;
      default:
        return 0;
    }
  }

  void _handleTap(int index) {
    String route;
    switch (index) {
      case 0:
        route = '/favorite';
        break;
      case 1:
        route = '/create_lesson';
        break;
      case 2:
        route = '/custom_lesson';
        break;
      default:
        route = '/favorite';
    }

    // Only navigate if we're on a different route
    if (currentRoute != route) {
      Navigator.pushReplacementNamed(navigatorKey.currentContext!, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: BottomNavigationBar(
        currentIndex: _getCurrentIndex(),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_music),
            label: 'All Lessons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Generate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.create),
            label: 'Custom',
          ),
        ],
        onTap: _handleTap,
      ),
    );
  }
}
