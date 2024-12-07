import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  // Extract common sign-in logic
  Future<void> _handleSignIn(BuildContext context, Future<User?> Function() signInMethod) async {
    final user = await signInMethod();
    if (user != null) {
      final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final userDocSnapshot = await userDocRef.get();
      if (!userDocSnapshot.exists) {
        await userDocRef.set({
          'name': user.displayName,
          'email': user.email,
        });
      }

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/create_lesson');
      }
    }
  }

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
                User? user = await AuthService().signInWithGoogle(context);
                if (user != null) {
                  DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                  DocumentSnapshot userDocSnapshot = await userDocRef.get();
                  if (!userDocSnapshot.exists) {
                    await userDocRef.set({
                      'name': user.displayName,
                      'email': user.email,
                      'nickname': '',
                    });
                  }
                  Navigator.pushReplacementNamed(context, '/create_lesson');
                }
              },
              child: const Text('Sign In with Google'),
            ),
            if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: ElevatedButton(
                  onPressed: () async {
                    User? user = await AuthService().signInWithApple(context);
                    if (user != null) {
                      Navigator.pushReplacementNamed(context, '/create_lesson');
                    }
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
