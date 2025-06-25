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

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadReminderTime();
    _fetchLessonGenerationCount();
  }

  Future<void> _fetchLessonGenerationCount() async {
    final apiCallsUsed = await LessonService.countAPIcallsByUser();
    setState(() {
      int limit = _premium ? LessonService.premiumAPILimit : LessonService.freeAPILimit;
      _apiCallsRemaining = apiCallsUsed >= limit ? 0 : limit - apiCallsUsed;
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
    await requestNotificationPermission();
    if (Platform.isAndroid) {
      bool? alarmPermissions = await requestExactAlarmPermission();
      if (alarmPermissions == null || !alarmPermissions) {
        return;
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? NotificationService.defaultReminderTime,
    );

    if (picked != null) {
      setState(() {
        _reminderTime = picked;
      });
      await _notificationService.scheduleDailyReminder(picked);
    }
  }

  Future<void> _cancelReminder() async {
    await _notificationService.cancelDailyReminder();
    setState(() {
      _reminderTime = null;
    });
  }

  void _deleteAccount() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ProfileHeader(name: _name, email: _email),
            // Combined account status and lesson generator card
            Card(
              elevation: 4,
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _premium
                        ? [
                            Colors.amber.withOpacity(0.05),
                            Theme.of(context).cardColor,
                          ]
                        : [
                            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                            Theme.of(context).cardColor,
                          ],
                  ),
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
                            'Daily Lesson Generator',
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
                            Icons.schedule,
                            size: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Resets at midnight',
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
                                'lesson${_apiCallsRemaining == 1 ? '' : 's'} remaining',
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
                      Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          Container(
                            height: 12,
                            width: MediaQuery.of(context).size.width * (_apiCallsRemaining / (_premium ? LessonService.premiumAPILimit : LessonService.freeAPILimit)),
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
                        ],
                      ),

                      const SizedBox(height: 8),
                      Text(
                        _premium ? 'Premium access: $_apiCallsRemaining of ${LessonService.premiumAPILimit} lessons' : '$_apiCallsRemaining of ${LessonService.freeAPILimit} lessons remaining',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                      ),

                      if (!_premium)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: _handleStoreNavigation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
                ProfileService.launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26"));
              },
            ),
            ProfileMenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () {
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
            DeleteAccountButton(onDelete: _deleteAccount),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
