import 'package:flutter/material.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/services/vocabulary_service.dart';

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
      case '/custom_lesson':
        return 1;
      case '/vocabulary_review':
        return 2;
      default:
        return 1; // Default to custom_lesson (middle tab)
    }
  }

  void _handleTap(int index) {
    String route;
    switch (index) {
      case 0:
        route = '/favorite';
        break;
      case 1:
        route = '/custom_lesson';
        break;
      case 2:
        route = '/vocabulary_review';
        break;
      default:
        route = '/custom_lesson'; // Default to custom_lesson
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
      child: FutureBuilder<int>(
        future: VocabularyService.getDueWordsCount(),
        builder: (context, snapshot) {
          final dueCount = snapshot.data ?? 0;

          // Debug print to see what's happening
          debugPrint('BottomMenuBar: Due words count = $dueCount, hasData = ${snapshot.hasData}, hasError = ${snapshot.hasError}');
          if (snapshot.hasError) {
            debugPrint('BottomMenuBar: Error = ${snapshot.error}');
          }

          return BottomNavigationBar(
            currentIndex: _getCurrentIndex(),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.library_music),
                label: 'All Lessons',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                label: 'Generate',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.text_snippet_sharp),
                    if (dueCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Review',
              ),
              // BottomNavigationBarItem(
              //   icon: Icon(Icons.auto_stories),
              //   label: 'Learning Track',
              // ),
            ],
            onTap: _handleTap,
          );
        },
      ),
    );
  }
}
