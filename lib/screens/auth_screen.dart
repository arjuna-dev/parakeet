import 'package:parakeet/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Parakeet!'),
      ),
      body: FractionallySizedBox(
        heightFactor: 0.8, // Adjust to control how much vertical space the content takes
        alignment: Alignment.center, // Ensures the content is vertically centered
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0, left: 30.0, right: 30.0),
              child: Image.asset(
                'assets/parakeet_logo_home.png',
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                await AuthService().signInWithGoogle(context);
              },
              child: const Text('Sign In with Google'),
            ),
            if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton(
                  onPressed: () async {
                    await AuthService().signInWithApple(context);
                  },
                  child: const Text('Sign in with Apple'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
