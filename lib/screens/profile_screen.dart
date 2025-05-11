import 'package:flutter/material.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/nickname_popup.dart';

import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/notification_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/widgets/profile_screen/streak_display.dart';
import 'package:parakeet/widgets/profile_screen/profile_header.dart';
import 'package:parakeet/widgets/profile_screen/profile_menu_item.dart';
import 'package:parakeet/widgets/profile_screen/delete_account_button.dart';
import 'package:parakeet/widgets/profile_screen/reminder_tile.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // Static method to show language settings dialog from anywhere
  static Future<void> showLanguageSettingsDialog(BuildContext context) async {
    await ProfileService.showLanguageSettingsDialog(context);
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
    if (time == null) {
      // If no time is set, schedule the default time (6 PM)
      await _notificationService.scheduleDailyReminder(NotificationService.defaultReminderTime);
      setState(() {
        _reminderTime = NotificationService.defaultReminderTime;
      });
    } else {
      setState(() {
        _reminderTime = time;
      });
    }
  }

  Future<void> _showTimePickerDialog() async {
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
    final updated = await ProfileService.showLanguageSettingsDialog(context);
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
            Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 14 : 16,
                  vertical: isSmallScreen ? 12 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$_apiCallsRemaining',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _apiCallsRemaining > 0 ? (_premium ? Colors.amber : Theme.of(context).colorScheme.primary) : Theme.of(context).colorScheme.error,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'lesson${_apiCallsRemaining == 1 ? '' : 's'} left',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _premium ? Colors.amber.withOpacity(0.2) : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _premium ? 'Premium' : 'Free',
                            style: TextStyle(
                              color: _premium ? Colors.amber.shade800 : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _apiCallsRemaining / (_premium ? LessonService.premiumAPILimit : LessonService.freeAPILimit),
                        child: Container(
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
                                color: _apiCallsRemaining > 0 ? (_premium ? Colors.amber.withOpacity(0.3) : Theme.of(context).colorScheme.primary.withOpacity(0.3)) : Theme.of(context).colorScheme.error.withOpacity(0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_apiCallsRemaining of ${_premium ? LessonService.premiumAPILimit : LessonService.freeAPILimit} lessons remaining',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                    if (!_premium && _apiCallsRemaining <= 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: _handleStoreNavigation,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_border,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Upgrade to Premium',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 14 : 16,
                  vertical: isSmallScreen ? 12 : 14,
                ),
                child: StreakDisplay(),
              ),
            ),
            ProfileMenuItem(
              icon: _premium ? Icons.star : Icons.star_border,
              iconColor: _premium ? Colors.amber : null,
              title: _premium ? 'Premium Member' : 'Free Account',
              subtitle: _premium ? 'Enjoy unlimited access' : 'Upgrade to premium for more features',
              onTap: _handleStoreNavigation,
            ),
            ProfileMenuItem(
              icon: Icons.translate,
              title: 'Language Settings',
              subtitle: 'Native: $_nativeLanguage • Target: $_targetLanguage • Level: $_languageLevel',
              onTap: _showLanguageSelectionDialog,
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
              icon: Icons.shopping_bag,
              title: 'Store',
              subtitle: 'View available packages and offers',
              onTap: _handleStoreNavigation,
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
            const Divider(),
            ProfileMenuItem(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () async {
                await _authService.signOut();
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),
            const SizedBox(height: 16),
            DeleteAccountButton(onDelete: _deleteAccount),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/profile"),
    );
  }
}
