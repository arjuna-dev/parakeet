import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class NicknamePopup extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onTextChanged);
    _loadUseNamePreference();
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
        SnackBar(
          content: Text("Your name is officially trending! But it’s time to pause and let it cool down. You can try again some other time!"),
        ),
      );
      return;
    }

    firstIndexUsed = Random().nextInt(greetings.length);
    String greeting = greetings[firstIndexUsed];

    try {
      String userId_N = FirebaseAuth.instance.currentUser!.uid + "_1";
      String text = "$greeting ${nicknameText}!";

      await CloudFunctionService.generateNicknameAudio(text, userId, userId_N);
      await _fetchAndPlayAudio(userId_N);
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

  Future<void> _fetchAndPlayAudio(String userId_N) async {
    bool audioFetched = false;

    while (!audioFetched) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        bool nicknameAudioExists = await urlExists(
          'https://storage.googleapis.com/user_nicknames/${userId_N}_nickname.mp3?timestamp=${timestamp}',
        );

        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        final duration = await player.setUrl('https://storage.googleapis.com/user_nicknames/${userId_N}_nickname.mp3?timestamp2=${timestamp2}');
        audioFetched = true;
        player.play();
      } catch (e) {
        await Future.delayed(Duration(seconds: 1));
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
      String newUserId_N = "${userId}_${i + 2 - firstIndexPassed}";
      String text = "${greetings[i]} ${_nicknameController.text}!";
      print("text: $text");
      await CloudFunctionService.generateNicknameAudio(text, userId, newUserId_N);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Stack(
        alignment: Alignment.center, // Centers the loading indicator
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nicknameController,
                maxLength: 25,
                decoration: const InputDecoration(
                  labelText: 'What should we call you?',
                ),
              ),
              Row(
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
                  const Text('Address me by name'),
                ],
              ),
            ],
          ),
          if (_isLoading)
            Positioned(
              child: CircularProgressIndicator(),
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
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: _isSubmitEnabled ? _handleGenerate : null,
          child: const Text('Generate'),
        ),
      ],
    );
  }
}
