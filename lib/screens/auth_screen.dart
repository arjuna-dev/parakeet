import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  // Extract common sign-in logic
  Future<void> _handleSignIn(
      BuildContext context, Future<User?> Function() signInMethod) async {
    final user = await signInMethod();
    if (user != null) {
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => _handleSignIn(
                context,
                () => AuthService().signInWithGoogle(context),
              ),
              child: const Text('Sign In with Google'),
            ),
            ElevatedButton(
              onPressed: () => _handleSignIn(
                context,
                () => AuthService().signInWithApple(context),
              ),
              child: const Text('Sign in with Apple'),
            ),
          ],
        ),
      ),
    );
  }
}
