import 'package:flutter/material.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/services/vocabulary_service.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BottomMenuBar extends StatelessWidget {
  final String currentRoute;

  // Static analytics manager to avoid recreating it
  static AnalyticsManager? _analyticsManager;
  static String? _lastUserId;

  const BottomMenuBar({
    super.key,
    required this.currentRoute,
  });

  AnalyticsManager? _getAnalyticsManager() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Only recreate if user changed or doesn't exist
      if (_analyticsManager == null || _lastUserId != user.uid) {
        _analyticsManager = AnalyticsManager(user.uid);
        _lastUserId = user.uid;
      }
      return _analyticsManager;
    } else {
      // Clear analytics manager if user is null
      _analyticsManager = null;
      _lastUserId = null;
    }
    return null;
  }

  int _getCurrentIndex() {
    switch (currentRoute) {
      case '/favorite':
        return 0;
      case '/custom_lesson':
        return 1;
      case '/vocabulary_review':
        return 2;
      case '/profile':
        return 3;
      default:
        return 0; // Default to home
    }
  }

  void _handleTap(int index) {
    String route;
    String analyticsAction;

    switch (index) {
      case 0:
        route = '/favorite';
        analyticsAction = 'bottom_nav_home_tapped';
        break;
      case 1:
        route = '/custom_lesson';
        analyticsAction = 'bottom_nav_learn_tapped';
        break;
      case 2:
        route = '/vocabulary_review';
        analyticsAction = 'bottom_nav_progress_tapped';
        break;
      case 3:
        route = '/profile';
        analyticsAction = 'bottom_nav_profile_tapped';
        break;
      default:
        route = '/favorite'; // Default to home
        analyticsAction = 'bottom_nav_default_tapped';
    }

    // Track the navigation attempt
    _getAnalyticsManager()?.storeAction(analyticsAction, 'from_$currentRoute');

    // Only navigate if we're on a different route
    if (currentRoute != route) {
      Navigator.pushReplacementNamed(navigatorKey.currentContext!, route);
    } else {
      _getAnalyticsManager()
          ?.storeAction('bottom_nav_same_route_tapped', route);
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
          debugPrint(
              'BottomMenuBar: Due words count = $dueCount, hasData = ${snapshot.hasData}, hasError = ${snapshot.hasError}');
          if (snapshot.hasError) {
            debugPrint('BottomMenuBar: Error = ${snapshot.error}');
            _getAnalyticsManager()?.storeAction(
                'bottom_nav_due_words_error', snapshot.error.toString());
          }

          return BottomNavigationBar(
            currentIndex: _getCurrentIndex(),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            backgroundColor: Colors.transparent,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: 'Learn',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.show_chart),
                    if (dueCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
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
                label: 'Progress',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            onTap: _handleTap,
          );
        },
      ),
    );
  }
}
