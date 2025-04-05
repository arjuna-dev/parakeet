import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/supported_language_codes.dart';
import 'package:parakeet/utils/greetings_list_all_languages.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {};
    }

    DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      return {
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'premium': userData['premium'] ?? false,
        'native_language': userData['native_language'] ?? 'English (US)',
        'target_language': userData['target_language'] ?? 'German',
        'language_level': userData['language_level'] ?? 'Absolute beginner (A1)',
      };
    }

    return {};
  }

  static Future<bool> showLanguageSettingsDialog(BuildContext context) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    // Fetch current user settings
    DocumentSnapshot userDoc = await firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) return false;

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
                                final String? selected = await _selectLanguageFromList(context, 'Select Native Language', languages, tempNativeLanguage);
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
                                final String? selected = await _selectLanguageFromList(context, 'Select Target Language', languages, tempTargetLanguage);
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
                                final String? selected = await _selectLanguageFromList(context, 'Select Language Level', languageLevels, tempLanguageLevel);
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

      // Generate greetings in the target language if it changed
      if (nativeLanguage != tempNativeLanguage) {
        await _generateNativeLanguageGreetings(user.uid, tempNativeLanguage);
      }

      // Show confirmation
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language settings updated')),
        );
      }

      return true;
    }

    return false;
  }

  // Helper method for language selection
  static Future<String?> _selectLanguageFromList(BuildContext context, String title, List<String> languages, String currentSelection) async {
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

  // Generate greetings in the target language
  static Future<void> _generateNativeLanguageGreetings(String userId, String nativeLanguage) async {
    try {
      // Fetch the user's nickname
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final nickname = userData['nickname'] as String?;

      if (nickname == null || nickname.isEmpty) return; // No nickname to generate greetings for

      // Check if target language has greetings
      if (!greetingsList.containsKey(nativeLanguage)) return;

      // Get greetings for the target language
      final targetGreetings = greetingsList[nativeLanguage]!;

      // Generate greetings in the background
      for (var i = 0; i < targetGreetings.length; i++) {
        final greeting = targetGreetings[i];
        final userIdN = "${userId}_${nativeLanguage}_${i + 1}";
        // Generate the greeting audio
        unawaited(CloudFunctionService.generateNicknameAudio("$greeting $nickname!", userId, userIdN, nativeLanguage));
      }
    } catch (e) {
      print("Error generating target language greetings: $e");
    }
  }

  static void launchURL(Uri url) async {
    await canLaunchUrl(url) ? await launchUrl(url) : throw 'Could not launch $url';
  }
}
