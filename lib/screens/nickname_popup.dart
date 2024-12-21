import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<String> greetings = ["hello", "How's it going", "Hi", "Hi, there", "Good day"];
  late int firstIndexUsed;
  String userId = FirebaseAuth.instance.currentUser!.uid;
  String? _currentNickname;

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

    // Check the call count before generating
    final callCount = await _getCallCount();
    if (callCount >= 11) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your name is officially trending! But it’s time to pause and let it cool down. You can try again some other time!"),
        ),
      );
      return;
    }

    firstIndexUsed = Random().nextInt(greetings.length);
    String greeting = greetings[firstIndexUsed];

    try {
      String userIdN = "${FirebaseAuth.instance.currentUser!.uid}_1";
      String text = "$greeting $nicknameText!";

      await CloudFunctionService.generateNicknameAudio(text, userId, userIdN);
      await _fetchAndPlayAudio(userIdN);
      await _saveNicknameToFirestore(nicknameText); // Save nickname to Firestore
      setState(() {
        _currentNickname = nicknameText;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your nickname has been saved! 🎉"),
        ),
      );
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<int> _getCallCount() async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userId).collection('api_call_count').doc('generate_nickname');
    final docSnapshot = await userDocRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      return data['call_count'] ?? 0;
    }
    return 0;
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

  Future<void> _generateRemainingAudios(String userId) async {
    String nicknameText = _nicknameController.text.trim();
    if (nicknameText.isEmpty) {
      return;
    }
    int firstIndexPassed = 0;
    for (int i = 0; i < greetings.length; i++) {
      if (i == firstIndexUsed) {
        firstIndexPassed = 1;
        continue;
      }
      String newUserIdN = "${userId}_${i + 2 - firstIndexPassed}";
      String text = "${greetings[i]} ${_nicknameController.text}!";
      print("text: $text");
      await CloudFunctionService.generateNicknameAudio(text, userId, newUserIdN);
    }
  }

  Future<void> _saveNicknameToFirestore(String nickname) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDocRef.update({'nickname': nickname});
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
            _generateRemainingAudios(userId);
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
