import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/streak_service.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/services/daily_lesson_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/screens/profile_screen.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppBarWithDrawer extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const AppBarWithDrawer({
    Key? key,
    required this.title,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _showDrawerMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation, Animation<double> secondaryAnimation) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(buildContext).size.width * 0.8,
                height: MediaQuery.of(buildContext).size.height,
                constraints: const BoxConstraints(
                  maxWidth: 320,
                  minWidth: 280,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(buildContext).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Compact Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                      decoration: BoxDecoration(
                        color: Theme.of(buildContext).colorScheme.primary.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.menu,
                            color: Theme.of(buildContext).colorScheme.primary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Menu',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(buildContext).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (Navigator.canPop(buildContext)) {
                                Navigator.pop(buildContext);
                              }
                            },
                            icon: const Icon(Icons.close, size: 14),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(buildContext).colorScheme.surface.withOpacity(0.5),
                              minimumSize: const Size(24, 24),
                              padding: const EdgeInsets.all(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Menu items - Scrollable
                    Expanded(
                      child: Column(
                        children: [
                          // Scrollable menu items
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal: MediaQuery.of(buildContext).size.width < 350 ? 16 : 20,
                                vertical: MediaQuery.of(buildContext).size.height < 700 ? 8 : 12,
                              ),
                              child: Column(
                                children: [
                                  // FutureBuilder<int>(
                                  //   future: _getDueWordsCount(),
                                  //   builder: (context, snapshot) {
                                  //     final dueCount = snapshot.data ?? 0;
                                  //     return _buildMenuItem(
                                  //       buildContext,
                                  //       icon: Icons.quiz_rounded,
                                  //       title: 'Vocabulary Review',
                                  //       subtitle: dueCount > 0 ? '$dueCount word${dueCount == 1 ? '' : 's'} ready for review' : 'Review words due for practice',
                                  //       onTap: () {
                                  //         if (Navigator.canPop(buildContext)) {
                                  //           Navigator.pop(buildContext);
                                  //         }
                                  //         Navigator.pushNamed(buildContext, '/vocabulary_review');
                                  //       },
                                  //       hasBadge: dueCount > 0,
                                  //       badgeCount: dueCount,
                                  //     );
                                  //   },
                                  // ),
                                  // SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 12 : 16),
                                  // _buildMenuItem(
                                  //   buildContext,
                                  //   icon: Icons.library_books,
                                  //   title: 'Word Bank',
                                  //   subtitle: 'View all your learned words',
                                  //   onTap: () {
                                  //     if (Navigator.canPop(buildContext)) {
                                  //       Navigator.pop(buildContext);
                                  //     }
                                  //     Navigator.pushNamed(buildContext, '/all_words');
                                  //   },
                                  // ),
                                  // SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 12 : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.language,
                                    title: 'Language Settings',
                                    subtitle: 'Change your learning languages',
                                    onTap: () {
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      ProfileScreen.showLanguageSettingsDialog(buildContext);
                                    },
                                  ),
                                  SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 12 : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.shopping_bag,
                                    title: 'Store',
                                    subtitle: 'View available packages and offers',
                                    onTap: () {
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      _handleStoreNavigation(buildContext);
                                    },
                                  ),
                                  SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 12 : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.person,
                                    title: 'Profile',
                                    subtitle: 'Settings and account info',
                                    onTap: () {
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      Navigator.pushNamed(buildContext, '/profile');
                                    },
                                  ),
                                  SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 16 : 24),
                                ],
                              ),
                            ),
                          ),

                          // Fixed bottom section
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(buildContext).size.width < 350 ? 16 : 20,
                              vertical: MediaQuery.of(buildContext).size.height < 700 ? 8 : 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(buildContext).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildStreakDisplay(buildContext),
                                SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 8 : 12),
                                _buildLessonProgressDisplay(buildContext),
                                SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 12 : 16),
                                _buildMenuItem(
                                  buildContext,
                                  icon: Icons.logout,
                                  title: 'Sign Out',
                                  subtitle: 'Log out of your account',
                                  iconColor: Colors.red,
                                  onTap: () async {
                                    if (Navigator.canPop(buildContext)) {
                                      Navigator.pop(buildContext);
                                    }
                                    await _showSignOutConfirmation(buildContext);
                                  },
                                ),
                                SizedBox(height: MediaQuery.of(buildContext).size.height < 700 ? 8 : 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  Widget _buildStreakDisplay(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    final StreakService streakService = StreakService();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.local_fire_department,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Learning Streak',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    FutureBuilder<int>(
                      future: streakService.getCurrentStreak(userId),
                      builder: (context, streakSnapshot) {
                        final streak = streakSnapshot.data ?? 0;
                        return Text(
                          '$streak day${streak == 1 ? '' : 's'} streak',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<bool>>(
            future: streakService.getLast7DaysActivity(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 30,
                  child: Center(
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final activityList = snapshot.data!;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final reversedIndex = 6 - index;
                  final isActive = activityList[reversedIndex];
                  final date = DateTime.now().subtract(Duration(days: 6 - index));
                  final isToday = index == 6;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: isActive
                            ? Icon(
                                Icons.check,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 12,
                              )
                            : null,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _getShortDayName(date),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getShortDayName(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  Widget _buildLessonProgressDisplay(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getLessonProgressData(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final data = snapshot.data!;
        final lessonsRemaining = data['remaining'] as int;
        final lessonsUsed = data['used'] as int;
        final isPremium = data['isPremium'] as bool;
        final limit = data['limit'] as int;
        final progress = limit > 0 ? (limit - lessonsRemaining) / limit : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Lessons',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$lessonsRemaining/$limit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: lessonsRemaining > 0
                                  ? (isPremium ? [Colors.amber.shade300, Colors.amber.shade700] : [Theme.of(context).colorScheme.primary.withOpacity(0.7), Theme.of(context).colorScheme.primary])
                                  : [Theme.of(context).colorScheme.error.withOpacity(0.7), Theme.of(context).colorScheme.error],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    // Show upgrade section when user has run out of lessons and is not premium
                    // OR show daily reset info for premium users
                    if (lessonsRemaining == 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    isPremium ? Icons.schedule : Icons.lock,
                                    size: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Daily limit reached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isPremium) ...[
                              // Show daily reset info for premium users
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 14,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Resets tomorrow',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Show upgrade button for non-premium users
                              GestureDetector(
                                onTap: () {
                                  // Close drawer first
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                  // Navigate to store
                                  _handleStoreNavigation(context);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      const Flexible(
                                        child: Text(
                                          'Upgrade for More',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: 0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.25),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          '10/day',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getLessonProgressData(String userId) async {
    try {
      // Get daily lesson progress data
      final progressData = await DailyLessonService.getDailyProgressData();

      return {
        'remaining': progressData['remaining'],
        'used': progressData['used'],
        'isPremium': progressData['isPremium'],
        'limit': progressData['limit'],
        'isDaily': true, // Flag to indicate this is daily system
      };
    } catch (e) {
      return {
        'remaining': DailyLessonService.freeUserDailyLimit,
        'used': 0,
        'isPremium': false,
        'limit': DailyLessonService.freeUserDailyLimit,
        'isDaily': true,
      };
    }
  }

  void _handleStoreNavigation(BuildContext context) {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.phone_android, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Mobile App Required'),
              ],
            ),
            content: const Text(
              'Please use the Parakeet mobile app to view and purchase premium features.',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StoreView()),
      );
    }
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    bool hasBadge = false,
    int badgeCount = 0,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? colorScheme.primary;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    final isNarrowScreen = MediaQuery.of(context).size.width < 350;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isNarrowScreen ? 10 : 12,
          vertical: isSmallScreen ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: isSmallScreen ? 28 : 32,
                  height: isSmallScreen ? 28 : 32,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                  ),
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: isSmallScreen ? 16 : 18,
                  ),
                ),
                if (hasBadge && badgeCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: isNarrowScreen ? 10 : 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isSmallScreen ? 14 : 15,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: isSmallScreen ? 16 : 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSignOutConfirmation(BuildContext context) async {
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut == true) {
      final authService = AuthService();
      await authService.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _showDrawerMenu(context),
      ),
    );
  }
}
