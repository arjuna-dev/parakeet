import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/supported_language_codes.dart';
import 'package:parakeet/utils/greetings_list_all_languages.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:parakeet/utils/save_analytics.dart';
import 'dart:async';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String _nativeLanguage = 'English (US)';
  String _targetLanguage = 'German';
  String _languageLevel = 'Absolute beginner';

  String _originalNativeLanguage = '';
  String _originalTargetLanguage = '';
  String _originalLanguageLevel = '';

  final List<String> _languageLevels = ['Absolute beginner', 'Beginner', 'Intermediate', 'Advanced'];

  late List<String> _languages;

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
    _languages = supportedLanguageCodes.keys.toList();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nativeLanguage = userData['native_language'] ?? 'English (US)';
          _targetLanguage = userData['target_language'] ?? 'German';
          _languageLevel = userData['language_level'] ?? 'Absolute beginner';

          // Store original values to check for changes
          _originalNativeLanguage = _nativeLanguage;
          _originalTargetLanguage = _targetLanguage;
          _originalLanguageLevel = _languageLevel;

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading current settings: $e');
      setState(() => _isLoading = false);
    }
  }

  bool get _hasChanges {
    return _nativeLanguage != _originalNativeLanguage || _targetLanguage != _originalTargetLanguage || _languageLevel != _originalLanguageLevel;
  }

  Future<void> _saveSettings() async {
    _trackUserAction('language_settings_save_button_pressed');

    if (!_hasChanges) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _isSaving = true);

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update user preferences in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'native_language': _nativeLanguage,
        'target_language': _targetLanguage,
        'language_level': _languageLevel,
      });

      // Generate greetings in the native language if it changed
      if (_nativeLanguage != _originalNativeLanguage) {
        await _generateNativeLanguageGreetings(user.uid, _nativeLanguage);
      }

      // Show confirmation
      if (mounted) {
        _trackUserAction('language_settings_saved_successfully', data: 'Native: $_nativeLanguage, Target: $_targetLanguage, Level: $_languageLevel');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Language settings updated')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings. Please try again.')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _generateNativeLanguageGreetings(String userId, String nativeLanguage) async {
    try {
      // Fetch the user's nickname
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final nickname = userData['nickname'] as String?;

      if (nickname == null || nickname.isEmpty) return;

      // Check if native language has greetings
      if (!greetingsList.containsKey(nativeLanguage)) return;

      // Get greetings for the native language
      final nativeGreetings = greetingsList[nativeLanguage]!;

      // Generate greetings in the background
      for (var i = 0; i < nativeGreetings.length; i++) {
        final greeting = nativeGreetings[i];
        final userIdN = "${userId}_${nativeLanguage}_${i + 1}";
        // Generate the greeting audio
        unawaited(CloudFunctionService.generateNicknameAudio("$greeting $nickname!", userId, userIdN, nativeLanguage));
      }
    } catch (e) {
      print("Error generating native language greetings: $e");
    }
  }

  Future<void> _selectLanguageFromList(
    String title,
    List<String> languages,
    String currentSelection,
    Function(String) onSelected,
  ) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Divider(),

              // Language list
              Expanded(
                child: ListView.builder(
                  itemCount: languages.length,
                  itemBuilder: (context, index) {
                    final language = languages[index];
                    final isSelected = language == currentSelection;

                    return ListTile(
                      title: Text(
                        language,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        Navigator.of(context).pop(language);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Configure your language preferences',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),

                  const SizedBox(height: 24),

                  // Native Language Card
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.home_rounded,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Native Language'),
                      subtitle: Text(
                        _nativeLanguage,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _trackUserAction('language_settings_native_language_selection_opened');
                        _selectLanguageFromList(
                          'Select Native Language',
                          _languages,
                          _nativeLanguage,
                          (selected) {
                            _trackUserAction('language_settings_native_language_selected', data: selected);
                            setState(() => _nativeLanguage = selected);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Target Language Card
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.translate_rounded,
                        color: colorScheme.secondary,
                      ),
                      title: const Text('Target Language'),
                      subtitle: Text(
                        _targetLanguage,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _trackUserAction('language_settings_target_language_selection_opened');
                        _selectLanguageFromList(
                          'Select Target Language',
                          _languages,
                          _targetLanguage,
                          (selected) {
                            _trackUserAction('language_settings_target_language_selected', data: selected);
                            setState(() => _targetLanguage = selected);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Language Level Card
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.school_rounded,
                        color: colorScheme.tertiary,
                      ),
                      title: const Text('Language Level'),
                      subtitle: Text(
                        _languageLevel,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        _trackUserAction('language_settings_language_level_selection_opened');
                        _selectLanguageFromList(
                          'Select Language Level',
                          _languageLevels,
                          _languageLevel,
                          (selected) {
                            _trackUserAction('language_settings_language_level_selected', data: selected);
                            setState(() => _languageLevel = selected);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button - always shown but disabled when no changes
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: (_isSaving || !_hasChanges) ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
