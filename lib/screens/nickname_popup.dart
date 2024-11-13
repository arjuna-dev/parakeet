import 'package:flutter/material.dart';
import 'package:parakeet/services/cloud_function_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NicknamePopup extends StatefulWidget {
  @override
  _NicknamePopupState createState() => _NicknamePopupState();
}

class _NicknamePopupState extends State<NicknamePopup> {
  final TextEditingController _nicknameController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitEnabled = false;

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
        // TODO: Fetch audio from google bucket https://storage.googleapis.com/user_nicknames/<user-id>_nickname.mp3
        // TODO: Play audio
        audioFetched = true;
      } catch (e) {
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter your nickname'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nicknameController,
            maxLength: 25,
            decoration: InputDecoration(
              labelText: 'What should I call you?',
            ),
          ),
          if (_isLoading) CircularProgressIndicator(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Ask me later'),
        ),
        TextButton(
          onPressed: _isSubmitEnabled ? _handleGenerate : null,
          child: Text('Generate'),
        ),
      ],
    );
  }
}
