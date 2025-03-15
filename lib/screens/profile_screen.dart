import 'package:flutter/material.dart';
import 'package:parakeet/screens/store_view.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/utils/supported_language_codes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/services/notification_service.dart';
import 'package:parakeet/widgets/streak_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  // Static method to show language settings dialog from anywhere
  static Future<void> showLanguageSettingsDialog(BuildContext context) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Fetch current user settings
    DocumentSnapshot userDoc = await firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data() as Map<String, dynamic>;
    String nativeLanguage = userData['native_language'] ?? 'English (US)';
    String targetLanguage = userData['target_language'] ?? 'German';
    String languageLevel = userData['language_level'] ?? 'Absolute beginner (A1)';

    final List<String> languageLevels = ['Absolute beginner (A1)', 'Beginner (A2-B1)', 'Intermediate (B2-C1)', 'Advanced (C2)'];
    final List<String> languages = supportedLanguageCodes.keys.toList();

    String tempNativeLanguage = nativeLanguage;
    String tempTargetLanguage = targetLanguage;
    String tempLanguageLevel = languageLevel;

    // Get screen size for responsive dialog
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final dialogWidth = screenSize.width > 600 ? 500.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.7;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: (screenSize.width - dialogWidth) / 2,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(maxHeight: dialogHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Language Settings',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Divider(),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Native language dropdown
                            ListTile(
                              title: const Text('Native Language'),
                              subtitle: Text(tempNativeLanguage),
                              trailing: const Icon(Icons.arrow_drop_down),
                              onTap: () async {
                                final String? selected = await _selectLanguageFromListStatic(context, 'Select Native Language', languages, tempNativeLanguage);
                                if (selected != null) {
                                  setState(() {
                                    tempNativeLanguage = selected;
                                  });
                                }
                              },
                            ),
                            const Divider(),
                            // Target language dropdown
                            ListTile(
                              title: const Text('Target Language'),
                              subtitle: Text(tempTargetLanguage),
                              trailing: const Icon(Icons.arrow_drop_down),
                              onTap: () async {
                                final String? selected = await _selectLanguageFromListStatic(context, 'Select Target Language', languages, tempTargetLanguage);
                                if (selected != null) {
                                  setState(() {
                                    tempTargetLanguage = selected;
                                  });
                                }
                              },
                            ),
                            const Divider(),
                            // Language level dropdown
                            ListTile(
                              title: const Text('Language Level'),
                              subtitle: Text(tempLanguageLevel),
                              trailing: const Icon(Icons.arrow_drop_down),
                              onTap: () async {
                                final String? selected = await _selectLanguageFromListStatic(context, 'Select Language Level', languageLevels, tempLanguageLevel);
                                if (selected != null) {
                                  setState(() {
                                    tempLanguageLevel = selected;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );

    if (confirmed == true && (nativeLanguage != tempNativeLanguage || targetLanguage != tempTargetLanguage || languageLevel != tempLanguageLevel)) {
      // Update user preferences in Firestore
      await firestore.collection('users').doc(user.uid).update({
        'native_language': tempNativeLanguage,
        'target_language': tempTargetLanguage,
        'language_level': tempLanguageLevel,
      });

      // Show confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language settings updated')),
        );
      }
    }
  }

  // Static helper method for language selection
  static Future<String?> _selectLanguageFromListStatic(BuildContext context, String title, List<String> languages, String currentSelection) async {
    // Get screen size for responsive dialog
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final dialogWidth = screenSize.width > 600 ? 500.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.6;

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: (screenSize.width - dialogWidth) / 2,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      final language = languages[index];
                      return ListTile(
                        title: Text(language),
                        selected: language == currentSelection,
                        trailing: language == currentSelection ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () {
                          Navigator.of(context).pop(language);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  String _name = '';
  String _email = '';
  bool _premium = false;
  final NotificationService _notificationService = NotificationService();
  TimeOfDay? _reminderTime;
  String _nativeLanguage = 'English (US)';
  String _targetLanguage = 'German';
  String _languageLevel = 'Absolute beginner (A1)';

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _fetchUserData();
    _loadReminderTime();
  }

  Future<void> _fetchUserData() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        print('userDoc email: ${userData['email']}');
        setState(() {
          _name = userData['name'] ?? '';
          _email = userData['email'] ?? '';
          _premium = userData['premium'] ?? false;
          _nativeLanguage = userData['native_language'] ?? 'English (US)';
          _targetLanguage = userData['target_language'] ?? 'German';
          _languageLevel = userData['language_level'] ?? 'Absolute beginner (A1)';
        });
      }
    }
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
    print('email: $_email');
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

  Widget _buildProfileHeader() {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    String getInitial() {
      if (_name.isNotEmpty) {
        return _name[0].toUpperCase();
      }
      if (_email.isNotEmpty) {
        return _email[0].toUpperCase();
      }
      return '?';
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 8 : 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: isSmallScreen ? 40 : 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                getInitial(),
                style: TextStyle(
                  fontSize: isSmallScreen ? 32 : 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Text(
              _name.isNotEmpty ? _name : _email,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_name.isNotEmpty)
              Text(
                _email,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 12,
        ),
        leading: Container(
          width: isSmallScreen ? 40 : 48,
          height: isSmallScreen ? 40 : 48,
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).colorScheme.primary,
            size: isSmallScreen ? 20 : 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 15 : 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.primary,
          size: isSmallScreen ? 24 : 28,
        ),
        onTap: onTap,
      ),
    );
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
    await ProfileScreen.showLanguageSettingsDialog(context);
    // Refresh the UI after settings are updated
    _fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            _buildProfileHeader(),
            Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
                child: StreakDisplay(),
              ),
            ),
            _buildMenuItem(
              icon: _premium ? Icons.star : Icons.star_border,
              iconColor: _premium ? Colors.amber : null,
              title: _premium ? 'Premium Member' : 'Free Account',
              subtitle: _premium ? 'Enjoy unlimited access' : 'Upgrade to premium for more features',
              onTap: _handleStoreNavigation,
            ),
            _buildMenuItem(
              icon: Icons.translate,
              title: 'Language Settings',
              subtitle: 'Native: $_nativeLanguage • Target: $_targetLanguage • Level: $_languageLevel',
              onTap: _showLanguageSelectionDialog,
            ),
            _buildMenuItem(
              icon: Icons.shopping_bag,
              title: 'Store',
              subtitle: 'View available packages and offers',
              onTap: _handleStoreNavigation,
            ),
            _buildMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs and contact information',
              onTap: () {
                _launchURL(Uri(scheme: "https", host: "gregarious-giant-4a5.notion.site", path: "/Terms-and-Conditions-107df60af3ed80d18e4fc94e05333a26"));
              },
            ),
            _buildMenuItem(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'View our privacy policy',
              onTap: () {
                _launchURL(Uri.parse("https://parakeet.world/privacypolicy"));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Daily Practice Reminder'),
              subtitle: Text(_reminderTime != null ? 'Reminder set for ${_reminderTime!.format(context)}' : 'No reminder set'),
              trailing: _reminderTime != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _cancelReminder,
                    )
                  : null,
              onTap: _showTimePickerDialog,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmallScreen ? 4 : 6),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.error.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: InkWell(
                  onTap: _deleteAccount,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 12 : 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete_forever,
                          color: colorScheme.error,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Delete Account',
                          style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 15 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
          ],
        ),
      ),
    );
  }
}

void _launchURL(Uri url) async {
  await canLaunchUrl(url) ? await launchUrl(url) : throw 'Could not launch $url';
}
