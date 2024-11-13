import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:parakeet/utils/constants.dart';

class NicknamePopup extends StatefulWidget {
  @override
  _NicknamePopupState createState() => _NicknamePopupState();
}

class _NicknamePopupState extends State<NicknamePopup> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitEnabled = false;
  final player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onTextChanged);
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

  Future<void> _handleGenerate() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      String text = _nicknameController.text;

      await CloudFunctionService.generateNicknameAudio(text, userId);
      await _fetchAndPlayAudio(userId);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAndPlayAudio(String userId) async {
    bool audioFetched = false;

    while (!audioFetched) {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        bool nicknameAudioExists = await urlExists(
          'https://storage.googleapis.com/user_nicknames/${userId}_nickname.mp3?timestamp=${timestamp}',
        );

        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        final duration = await player.setUrl('https://storage.googleapis.com/user_nicknames/${userId}_nickname.mp3?timestamp2=${timestamp2}');
        audioFetched = true;
        player.play();
      } catch (e) {
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter your name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nicknameController,
            maxLength: 25,
            decoration: InputDecoration(
              labelText: 'What should we call you?',
            ),
          ),
          if (_isLoading) CircularProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            player.dispose();
            Navigator.of(context).pop();
          },
          child: Text('Close'),
        ),
        TextButton(
          onPressed: _isSubmitEnabled ? _handleGenerate : null,
          child: Text('Generate'),
        ),
      ],
    );
  }
}
