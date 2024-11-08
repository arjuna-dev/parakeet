import 'package:parakeet/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Parakeet!'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                User? user = await AuthService().signInWithGoogle(context);
                if (user != null && context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text('Sign In with Google'),
            ),
            ElevatedButton(
              onPressed: () async {
                User? user = await AuthService().signInWithApple(context);
                if (user != null) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text('Sign in with Apple'),
            ),
          ],
        ),
      ),
    );
  }
}
