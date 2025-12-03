import 'package:flutter/material.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/nickname_popup.dart';

import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/notification_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/widgets/profile_screen/profile_header.dart';
import 'package:parakeet/widgets/profile_screen/profile_menu_item.dart';
import 'package:parakeet/widgets/profile_screen/delete_account_button.dart';
import 'package:parakeet/widgets/profile_screen/reminder_tile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/widgets/onboarding_screen/notifications_step.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // Static method to navigate to language settings from anywhere
  static Future<void> showLanguageSettingsDialog(BuildContext context) async {
    await ProfileService.navigateToLanguageSettings(context);
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  String _name = '';
  String _email = '';
  bool _premium = false;
  final NotificationService _notificationService = NotificationService();
  TimeOfDay? _reminderTime;
  String _nativeLanguage = 'English (US)';
  String _targetLanguage = 'German';
  String _languageLevel = 'Absolute beginner (A1)';

  int _apiCallsRemaining = 0;

  void _trackUserAction(String action, {String? data}) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final analyticsManager = AnalyticsManager(user.uid);
      analyticsManager.storeAction(action, data ?? '');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadReminderTime();
    _fetchLessonGenerationCount();
  }

  Future<void> _fetchLessonGenerationCount() async {
    final currentCredits = await LessonService.getCurrentCredits();
    setState(() {
      _apiCallsRemaining = currentCredits;
    });
  }

  Future<void> _fetchUserData() async {
    final userData = await ProfileService.fetchUserData();
    setState(() {
      _name = userData['name'] ?? '';
      _email = userData['email'] ?? '';
      _premium = userData['premium'] ?? false;
      _nativeLanguage = userData['native_language'] ?? 'English (US)';
      _targetLanguage = userData['target_language'] ?? 'German';
      _languageLevel = userData['language_level'] ?? 'Absolute beginner (A1)';
    });
    // Update lesson count after premium status is fetched
    _fetchLessonGenerationCount();
  }

  Future<void> _loadReminderTime() async {
    final time = await _notificationService.getScheduledReminderTime();
    setState(() {
      _reminderTime = time;
    });
  }

  Future<void> _showTimePickerDialog() async {
    _trackUserAction('profile_reminder_time_picker_opened');

    // Ensure NotificationService is initialized
    try {
      await _notificationService.initialize();
    } catch (e) {
      print('Error initializing notification service: $e');
    }

    // Request permissions
    try {
      await requestNotificationPermission();
      if (Platform.isAndroid) {
        bool? alarmPermissions = await requestExactAlarmPermission();
        if (alarmPermissions == null || !alarmPermissions) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Exact alarm permission is required for daily reminders. Please enable it in settings.'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          // Still allow user to set time, but warn them
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
      // Continue anyway - user can still set the time
    }

    // Show time picker
    final colorScheme = Theme.of(context).colorScheme;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? NotificationService.defaultReminderTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: colorScheme.copyWith(
              primary: colorScheme.primary,
              onPrimary: colorScheme.onPrimary,
              surface: colorScheme.surfaceContainerHighest,
              onSurface: colorScheme.onSurface,
              onSurfaceVariant: colorScheme.onSurfaceVariant,
              secondary: colorScheme.secondary,
              onSecondary: colorScheme.onSecondary,
              surfaceContainerHighest: colorScheme.surfaceContainerHighest,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: colorScheme.surfaceContainerHighest,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  width: 1,
                ),
              ),
              titleTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              contentTextStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: colorScheme.surfaceContainerHighest,
              hourMinuteColor: colorScheme.surfaceContainerHighest,
              hourMinuteTextColor: colorScheme.onSurface,
              dayPeriodColor: colorScheme.primaryContainer,
              dayPeriodTextColor: colorScheme.onPrimaryContainer,
              dialHandColor: colorScheme.primary,
              dialBackgroundColor: colorScheme.surfaceContainerHighest,
              dialTextColor: colorScheme.onSurface,
              entryModeIconColor: colorScheme.primary,
              dayPeriodTextStyle: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
              hourMinuteTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              helpTextStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
              inputDecorationTheme: InputDecorationTheme(
                fillColor: colorScheme.surfaceContainerHighest,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _trackUserAction('profile_reminder_time_selected', data: '${picked.hour}:${picked.minute}');
      try {
        await _notificationService.scheduleDailyReminder(picked);
        setState(() {
          _reminderTime = picked;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Daily reminder set for ${picked.format(context)}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error scheduling reminder: $e');
        if (mounted) {
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

  Future<void> _cancelReminder() async {
    _trackUserAction('profile_reminder_cancelled');
    await _notificationService.cancelDailyReminder();
    setState(() {
      _reminderTime = null;
    });
  }

  void _deleteAccount() async {
    _trackUserAction('profile_delete_account_button_pressed');
    final colorScheme = Theme.of(context).colorScheme;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: colorScheme.surfaceContainerHighest,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
              width: 1,
            ),
          ),
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
                        _trackUserAction('profile_delete_account_cancelled');
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
                        _trackUserAction('profile_delete_account_confirmed');
                        Navigator.of(context).pop(true);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
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

    if (confirm == true) {
      try {
        await _authService.deleteAccount();
        // Navigate to login or home screen after account deletion
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } catch (e) {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  void _handleStoreNavigation() {
    if (kIsWeb) {
      _trackUserAction('profile_store_navigation_attempted_web');
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
      _trackUserAction('profile_store_navigation_mobile');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const StoreView()),
      );
    }
  }

  Future<void> _showLanguageSelectionDialog() async {
    final updated = await ProfileService.navigateToLanguageSettings(context);
    if (updated) {
      // Refresh the UI after settings are updated
      _fetchUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return Scaffold(
      appBar: const AppBarWithDrawer(
        title: 'Profile',
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(name: _name, email: _email),
            // Combined account status and lesson generator card
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 6 : 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _premium ? Colors.amber.withOpacity(0.3) : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _premium ? Icons.star : Icons.person,
                                color: _premium ? Colors.amber : Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _premium ? 'Premium Account' : 'Free Account',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _premium ? Colors.amber.shade800 : Theme.of(context).colorScheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Lesson generator section
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Daily Lessons',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.today,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _premium ? 'Refills daily with subscription' : 'Limited daily lessons for free users',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$_apiCallsRemaining',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _apiCallsRemaining > 0 ? (_premium ? Colors.amber.shade700 : Theme.of(context).colorScheme.primary) : Theme.of(context).colorScheme.error,
                                    ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'lesson${_apiCallsRemaining == 1 ? '' : 's'} remaining today',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final limit = _premium ? 10 : 2;
                          final progress = limit > 0 ? (_apiCallsRemaining / limit).clamp(0.0, 1.0) : 0.0;
                          
                          return Stack(
                            children: [
                              Container(
                                height: 12,
                                width: constraints.maxWidth,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: progress,
                                child: Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _apiCallsRemaining > 0
                                          ? (_premium ? [Colors.amber.shade300, Colors.amber.shade700] : [Theme.of(context).colorScheme.primary.withOpacity(0.7), Theme.of(context).colorScheme.primary])
                                          : [Theme.of(context).colorScheme.error.withOpacity(0.7), Theme.of(context).colorScheme.error],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            _apiCallsRemaining > 0 ? (_premium ? Colors.amber.withOpacity(0.3) : Theme.of(context).colorScheme.primary.withOpacity(0.3)) : Theme.of(context).colorScheme.error.withOpacity(0.3),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      Text(
                        _premium ? 'Premium: $_apiCallsRemaining of 10 daily lessons remaining' : '$_apiCallsRemaining of 2 daily lessons remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),

                      if (!_premium)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: () {
                              _trackUserAction('profile_upgrade_to_premium_button_pressed');
                              _handleStoreNavigation();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              minimumSize: const Size(double.infinity, 40),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Upgrade to Premium',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            ProfileMenuItem(
              icon: Icons.edit,
              title: 'Edit Nickname',
              subtitle: 'Change how the app addresses you',
              onTap: () {
                _trackUserAction('profile_edit_nickname_menu_item_pressed');
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return const NicknamePopup();
                  },
                ).then((_) {
                  // Refresh user data after nickname change
                  _fetchUserData();
                });
              },
            ),
            ProfileMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs and contact information',
              onTap: () {
                _trackUserAction('profile_help_support_menu_item_pressed');
                ProfileService.launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26"));
              },
            ),
            ProfileMenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () {
                _trackUserAction('profile_privacy_policy_menu_item_pressed');
                ProfileService.launchURL(Uri.parse("https://parakeet.world/privacypolicy"));
              },
            ),
            const Divider(),
            ReminderTile(
              reminderTime: _reminderTime,
              onTap: _showTimePickerDialog,
              onClear: _reminderTime != null ? _cancelReminder : null,
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 24),
            DeleteAccountButton(onDelete: _deleteAccount),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(
        currentRoute: '/profile',
      ),
    );
  }
}
