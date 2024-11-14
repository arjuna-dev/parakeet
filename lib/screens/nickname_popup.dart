import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

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
    setState(() {
      _isLoading = true;
    });
    firstIndexUsed = Random().nextInt(greetings.length);
    String greeting = greetings[firstIndexUsed];

    try {
      String userId_N = FirebaseAuth.instance.currentUser!.uid + "_1";
      String text = "$greeting ${_nicknameController.text}!";

      await CloudFunctionService.generateNicknameAudio(text, userId_N);
      await _fetchAndPlayAudio(userId_N);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _generateRemainingAudios(String text, String userId) async {
    for (int i = 0; i < greetings.length; i++) {
      if (i == firstIndexUsed) {
        continue;
      }
      String newUserId_N = "${userId}_${i + 2}";
      await CloudFunctionService.generateNicknameAudio(greetings[i], newUserId_N);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter your name'),
      content: Column(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Use name'),
              Switch(
                value: _useName,
                onChanged: (value) {
                  setState(() {
                    _useName = value;
                  });
                  _saveUseNamePreference(value);
                },
              ),
            ],
          ),
          if (_isLoading) CircularProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            String userId = FirebaseAuth.instance.currentUser!.uid;
            String text = _nicknameController.text;
            await _generateRemainingAudios(text, userId);
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
