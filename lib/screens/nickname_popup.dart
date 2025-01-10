import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/utils/greetings_list_all_languages.dart';
import 'dart:async';
import '../utils/native_language_list.dart';
import 'dart:math';

class NicknamePopup extends StatefulWidget {
  const NicknamePopup({super.key});

  @override
  _NicknamePopupState createState() => _NicknamePopupState();
}

class _NicknamePopupState extends State<NicknamePopup> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitEnabled = false;
  bool _useName = true;
  final player = AudioPlayer();
  String userId = FirebaseAuth.instance.currentUser!.uid;
  String? _currentNickname;
  String _selectedLanguage = "English (US)"; // Add this line near other state variables
  int? _usedGreetingIndex; // Add this near other state variables

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onTextChanged);
    _loadUseNamePreference();
    _fetchNickname();
  }

  Future<void> _fetchNickname() async {
    try {
      final String? nickname = await fetchCurrentNickname();
      setState(() {
        _currentNickname = nickname;
        _isLoading = false; // Loading complete
      });
    } catch (error) {
      // Handle error (optional)
      setState(() {
        _isLoading = false; // Loading complete even if there's an error
      });
      print("Error fetching nickname: $error");
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isSubmitEnabled = _nicknameController.text.isNotEmpty;
    });
  }

  Future<void> _loadUseNamePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useName = prefs.getBool('addressByNickname') ?? true;
    });
  }

  Future<void> _saveUseNamePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('addressByNickname', value);
  }

  Future<bool> _checkAndUpdateCallCount() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final today = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

    try {
      return await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('api_call_count').doc('generate_nickname');

        final userDocSnapshot = await transaction.get(userDocRef);

        if (!userDocSnapshot.exists) {
          // If document doesn't exist, create it with count 1
          transaction.set(userDocRef, {'last_call_date': today, 'call_count': 1});
          return true;
        } else {
          // Document exists, check count and date
          if (userDocSnapshot.get('last_call_date') == today) {
            if (userDocSnapshot.get('call_count') >= 1) {
              // Limit reached
              return false;
            } else {
              // Increment count
              transaction.update(userDocRef, {'call_count': FieldValue.increment(1)});
              return true;
            }
          } else {
            // New day, reset count
            transaction.set(userDocRef, {'last_call_date': today, 'call_count': 1});
            return true;
          }
        }
      });
    } catch (e) {
      print('Error in transaction: $e');
      return false;
    }
  }

  Future<void> _handleGenerate() async {
    String nicknameText = _nicknameController.text.trim();
    if (nicknameText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Hmmm, it seems like you haven't entered a nickname yet! 🧐"),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final canProceed = await _checkAndUpdateCallCount();
    if (!canProceed) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your name is officially trending! But it's time to pause and let it cool down. You can try again some other time!"),
        ),
      );
      return;
    }

    try {
      // Generate and play greeting in selected language with random greeting
      final selectedGreetings = greetingsList[_selectedLanguage]!;
      _usedGreetingIndex = Random().nextInt(selectedGreetings.length);
      final randomGreeting = selectedGreetings[_usedGreetingIndex!];
      final mainUserIdN = "${FirebaseAuth.instance.currentUser!.uid}_1";

      await CloudFunctionService.generateNicknameAudio("$randomGreeting $nicknameText!", userId, mainUserIdN, _selectedLanguage);
      await _fetchAndPlayAudio(mainUserIdN);
      await _saveNicknameToFirestore(nicknameText);

      setState(() {
        _currentNickname = nicknameText;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your nickname has been saved!"),
        ),
      );

      // Generate remaining greetings in background
      unawaited(_generateRemainingGreetings(nicknameText));
    } catch (e) {
      print("Error generating nicknames: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("There was an error generating your nickname. Please try again."),
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String?> fetchCurrentNickname() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('nickname') && data['nickname'].isNotEmpty) {
          return data['nickname'];
        }
      }
    }
    return null;
  }

  Future<void> _fetchAndPlayAudio(String useridN) async {
    bool audioFetched = false;

    while (!audioFetched) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        await urlExists(
          'https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp=$timestamp',
        );

        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        await player.setUrl('https://storage.googleapis.com/user_nicknames/${useridN}_nickname.mp3?timestamp2=$timestamp2');
        audioFetched = true;
        player.play();
      } catch (e) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _saveNicknameToFirestore(String nickname) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.update({'nickname': nickname});
    }
  }

  Future<void> _generateRemainingGreetings(String nicknameText) async {
    try {
      int audioIndex = 2; // Start from 2 since 1 is used for main English greeting

      // First generate remaining English (US) greetings
      final selectedGreetings = greetingsList[_selectedLanguage]!;

      // Generate remaining greetings for selected language, skipping the used one
      for (var i = 0; i < selectedGreetings.length; i++) {
        if (i == _usedGreetingIndex) continue; // Skip the greeting we already generated
        final greeting = selectedGreetings[i];
        final userIdN = "${FirebaseAuth.instance.currentUser!.uid}_$audioIndex";
        unawaited(CloudFunctionService.generateNicknameAudio("$greeting $nicknameText!", userId, userIdN, _selectedLanguage));
        audioIndex++;
      }
    } catch (e) {
      print("Error queuing remaining greetings: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Some additional greetings could not be queued. The main greeting is still available."),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      title: Text(
        _currentNickname != null ? "Hi, $_currentNickname!" : "Hi, there!",
        style: TextStyle(
          fontSize: isSmallScreen ? 20 : 24,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),
      content: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nicknameController,
                      maxLength: 25,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      decoration: InputDecoration(
                        labelText: _currentNickname != null ? 'Want to change your name?' : "What should we call you?",
                        labelStyle: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                        counterStyle: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 4 : 8,
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: InputDecoration(
                          labelText: 'Select Language',
                          labelStyle: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          border: InputBorder.none,
                        ),
                        items: nativeLanguageCodes.keys.map((String language) {
                          return DropdownMenuItem<String>(
                            value: language,
                            child: Text(
                              language,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedLanguage = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 8 : 12,
                        vertical: isSmallScreen ? 4 : 8,
                      ),
                      child: Row(
                        children: [
                          Switch(
                            value: _useName,
                            onChanged: (value) {
                              setState(() {
                                _useName = value;
                              });
                              _saveUseNamePreference(value);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Address me by name',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            player.dispose();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onSurfaceVariant,
          ),
          child: Text(
            'Close',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
            ),
          ),
        ),
        FilledButton(
          onPressed: _isSubmitEnabled ? _handleGenerate : null,
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            disabledBackgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Create & Save',
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
      actionsPadding: EdgeInsets.all(isSmallScreen ? 12 : 16),
    );
  }
}
