import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/streak_service.dart';
import 'package:parakeet/services/daily_lesson_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/screens/profile_screen.dart';
import 'package:parakeet/screens/nickname_popup.dart';
import 'package:parakeet/services/notification_service.dart';
import 'dart:io';
import 'package:parakeet/widgets/onboarding_screen/notifications_step.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/utils/save_analytics.dart';
import 'package:parakeet/theme/theme.dart';

class AppBarWithDrawer extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final IconData? icon;

  const AppBarWithDrawer({
    Key? key,
    required this.title,
    this.icon,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  AnalyticsManager? _getAnalyticsManager() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return AnalyticsManager(user.uid);
    }
    return null;
  }

  void _showDrawerMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext buildContext, Animation<double> animation,
          Animation<double> secondaryAnimation) {
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
                    // User Info Header
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getUserInfo(),
                      builder: (context, snapshot) {
                        final user = FirebaseAuth.instance.currentUser;
                        final name = snapshot.data?['name'] ?? user?.displayName ?? 'User';
                        final email = snapshot.data?['email'] ?? user?.email ?? '';
                        
                        return Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
                      decoration: BoxDecoration(
                        color: Theme.of(buildContext)
                            .colorScheme
                            .primary
                            .withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(20),
                        ),
                      ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                              Row(
                                children: [
                          Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                              style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                color: Theme.of(buildContext)
                                    .colorScheme
                                    .onSurface,
                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (email.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(buildContext)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _getAnalyticsManager()?.storeAction(
                                  'app_drawer_close_button_tapped');
                              if (Navigator.canPop(buildContext)) {
                                Navigator.pop(buildContext);
                              }
                            },
                                    icon: const Icon(Icons.close, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(buildContext)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.5),
                                      minimumSize: const Size(32, 32),
                                      padding: const EdgeInsets.all(4),
                            ),
                          ),
                        ],
                      ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Menu items - Scrollable
                    Expanded(
                      child: Column(
                        children: [
                          // Scrollable menu items
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    MediaQuery.of(buildContext).size.width < 350
                                        ? 16
                                        : 20,
                                vertical:
                                    MediaQuery.of(buildContext).size.height <
                                            700
                                        ? 8
                                        : 12,
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
                                      _getAnalyticsManager()?.storeAction(
                                          'app_drawer_language_settings_tapped');
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      ProfileScreen.showLanguageSettingsDialog(
                                          buildContext);
                                    },
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 12
                                          : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.shopping_bag,
                                    title: 'Store',
                                    subtitle:
                                        'View available packages and offers',
                                    onTap: () {
                                      _getAnalyticsManager()?.storeAction(
                                          'app_drawer_store_tapped');
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      _handleStoreNavigation(buildContext);
                                    },
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 12
                                          : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.edit,
                                    title: 'Edit Nickname',
                                    subtitle: 'Change how the app addresses you',
                                    onTap: () {
                                      _getAnalyticsManager()?.storeAction(
                                          'app_drawer_edit_nickname_tapped');
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      showDialog(
                                        context: buildContext,
                                        builder: (context) {
                                          return const NicknamePopup();
                                        },
                                      );
                                    },
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 12
                                          : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.help_outline,
                                    title: 'Help & Support',
                                    subtitle: 'FAQs and contact information',
                                    onTap: () {
                                      _getAnalyticsManager()?.storeAction(
                                          'app_drawer_help_support_tapped');
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      ProfileService.launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26"));
                                    },
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 12
                                          : 16),
                                  _buildMenuItem(
                                    buildContext,
                                    icon: Icons.privacy_tip_outlined,
                                    title: 'Privacy Policy',
                                    subtitle: 'View our privacy policy',
                                    onTap: () {
                                      _getAnalyticsManager()?.storeAction(
                                          'app_drawer_privacy_policy_tapped');
                                      if (Navigator.canPop(buildContext)) {
                                        Navigator.pop(buildContext);
                                      }
                                      ProfileService.launchURL(Uri.parse("https://parakeet.world/privacypolicy"));
                                    },
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 16
                                          : 24),
                                  const Divider(),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 8
                                          : 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: InkWell(
                                      onTap: () async {
                                        if (Navigator.canPop(buildContext)) {
                                          Navigator.pop(buildContext);
                                        }
                                        await _showDeleteAccountConfirmation(buildContext);
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Theme.of(buildContext).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'Delete Account',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Theme.of(buildContext).colorScheme.onSurfaceVariant.withOpacity(0.6),
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                      height: MediaQuery.of(buildContext)
                                                  .size
                                                  .height <
                                              700
                                          ? 16
                                          : 24),
                                ],
                              ),
                            ),
                          ),

                          // Fixed bottom section
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  MediaQuery.of(buildContext).size.width < 350
                                      ? 16
                                      : 20,
                              vertical:
                                  MediaQuery.of(buildContext).size.height < 700
                                      ? 8
                                      : 12,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(buildContext)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildStreakDisplay(buildContext),
                                SizedBox(
                                    height: MediaQuery.of(buildContext)
                                                .size
                                                .height <
                                            700
                                        ? 8
                                        : 12),
                                _buildLessonProgressDisplay(buildContext),
                                SizedBox(
                                    height: MediaQuery.of(buildContext)
                                                .size
                                                .height <
                                            700
                                        ? 12
                                        : 16),
                                _buildReminderTile(buildContext),
                                SizedBox(
                                    height: MediaQuery.of(buildContext)
                                                .size
                                                .height <
                                            700
                                        ? 12
                                        : 16),
                                _buildMenuItem(
                                  buildContext,
                                  icon: Icons.logout,
                                  title: 'Sign Out',
                                  subtitle: 'Log out of your account',
                                  iconColor:
                                      Theme.of(buildContext).colorScheme.error,
                                  onTap: () async {
                                    _getAnalyticsManager()?.storeAction(
                                        'app_drawer_sign_out_tapped');
                                    if (Navigator.canPop(buildContext)) {
                                      Navigator.pop(buildContext);
                                    }
                                    await _showSignOutConfirmation(
                                        buildContext);
                                  },
                                ),
                                SizedBox(
                                    height: MediaQuery.of(buildContext)
                                                .size
                                                .height <
                                            700
                                        ? 8
                                        : 16),
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
      transitionBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) {
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
                  final date =
                      DateTime.now().subtract(Duration(days: 6 - index));
                  final isToday = index == 6;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
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
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3),
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
        // Progress based on remaining lessons (filled when more lessons available)
        final progress = limit > 0 ? lessonsRemaining / limit : 0.0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withOpacity(0.3),
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
                          'Daily Lessons Remaining',
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: lessonsRemaining > 0
                                  ? (isPremium
                                      ? [
                                          Colors.amber.shade300,
                                          Colors.amber.shade700
                                        ]
                                      : [
                                          Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.7),
                                          Theme.of(context).colorScheme.primary
                                        ])
                                  : [
                                      Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withOpacity(0.7),
                                      Theme.of(context).colorScheme.error
                                    ],
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
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh
                              .withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
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
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    isPremium ? Icons.schedule : Icons.lock,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Daily limit reached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isPremium) ...[
                              // Show daily reset info for premium users
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 14,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Resets tomorrow',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Show upgrade button for non-premium users
                              GestureDetector(
                                onTap: () {
                                  _getAnalyticsManager()?.storeAction(
                                      'app_drawer_upgrade_button_tapped');
                                  // Close drawer first
                                  if (Navigator.canPop(context)) {
                                    Navigator.pop(context);
                                  }
                                  // Navigate to store
                                  _handleStoreNavigation(context);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.25),
                                          borderRadius:
                                              BorderRadius.circular(12),
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

  Future<Map<String, dynamic>> _getUserInfo() async {
    try {
      final userData = await ProfileService.fetchUserData();
      return {
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
      };
    } catch (e) {
      final user = FirebaseAuth.instance.currentUser;
      return {
        'name': user?.displayName ?? 'User',
        'email': user?.email ?? '',
      };
    }
  }

  Widget _buildReminderTile(BuildContext context) {
    return FutureBuilder<TimeOfDay?>(
      future: NotificationService().getScheduledReminderTime(),
      builder: (context, snapshot) {
        final reminderTime = snapshot.data;
        final notificationService = NotificationService();
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Icon(
                Icons.notifications,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Daily Practice Reminder',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                reminderTime != null 
                    ? 'Set for ${reminderTime.format(context)}' 
                    : 'No reminder set',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: reminderTime != null
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: () async {
                        await notificationService.cancelDailyReminder();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reminder cancelled'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    )
                  : null,
              onTap: () async {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                await _showTimePickerDialog(context);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTimePickerDialog(BuildContext context) async {
    final notificationService = NotificationService();
    final currentTime = await notificationService.getScheduledReminderTime();
    
    try {
      await notificationService.initialize();
    } catch (e) {
      print('Error initializing notification service: $e');
    }

    try {
      await requestNotificationPermission();
      if (Platform.isAndroid) {
        bool? alarmPermissions = await requestExactAlarmPermission();
        if (alarmPermissions == null || !alarmPermissions) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exact alarm permission is required for daily reminders. Please enable it in settings.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }

    final colorScheme = Theme.of(context).colorScheme;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime ?? NotificationService.defaultReminderTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme,
            dialogTheme: DialogThemeData(
              backgroundColor: colorScheme.surfaceContainerHighest,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && context.mounted) {
      try {
        await notificationService.scheduleDailyReminder(picked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Daily reminder set for ${picked.format(context)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to set reminder: ${e.toString()}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteAccountConfirmation(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: ParakeetDialogTheme.background(colorScheme),
          surfaceTintColor: Colors.transparent,
          shape: ParakeetDialogTheme.alertShape(colorScheme),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to delete your account? This action cannot be undone.',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true && context.mounted) {
      try {
        final authService = AuthService();
        await authService.deleteAccount();
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      }
    }
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
      _getAnalyticsManager()?.storeAction('app_store_navigation_blocked_web');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            backgroundColor: ParakeetDialogTheme.background(cs),
            surfaceTintColor: Colors.transparent,
            shape: ParakeetDialogTheme.alertShape(cs),
            title: Row(
              children: [
                Icon(Icons.phone_android, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Mobile App Required',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Text(
              'Please use the Parakeet mobile app to view and purchase premium features.',
              style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _getAnalyticsManager()
                      ?.storeAction('app_store_web_dialog_closed');
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(foregroundColor: cs.primary),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      _getAnalyticsManager()?.storeAction('app_store_navigation_mobile');
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
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: TextStyle(
                          color: colorScheme.onError,
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
    final colorScheme = Theme.of(context).colorScheme;
    final bool? shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: ParakeetDialogTheme.background(colorScheme),
          surfaceTintColor: Colors.transparent,
          shape: ParakeetDialogTheme.alertShape(colorScheme),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to sign out?',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        _getAnalyticsManager()
                            ?.storeAction('app_sign_out_dialog_cancelled');
                        Navigator.of(context).pop(false);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        _getAnalyticsManager()
                            ?.storeAction('app_sign_out_dialog_confirmed');
                        Navigator.of(context).pop(true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldSignOut == true) {
      _getAnalyticsManager()?.storeAction('app_sign_out_executed');
      final authService = AuthService();
      await authService.signOut();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          _getAnalyticsManager()?.storeAction('app_menu_button_tapped');
          _showDrawerMenu(context);
        },
      ),
    );
  }
}
