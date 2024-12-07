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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton(
              onPressed: () async {
                // Sign in with Google
                User? user = await AuthService().signInWithGoogle(context);
                if (user != null) {
                  // Get reference to the user's document in Firestore
                  DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

                  // Check if user already exists in Firestore
                  DocumentSnapshot userDocSnapshot = await userDocRef.get();
                  if (!userDocSnapshot.exists) {
                    // User does not exist, create new document
                    await userDocRef.set({
                      'name': user.displayName,
                      'email': user.email,
                      'nickname': '',
                      // Add more user data as needed
                    });
                  }

                  Navigator.pushReplacementNamed(context, '/create_lesson');
                }
              },
              child: const Text('Sign In with Google'),
            ),
            if (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
              ElevatedButton(
                onPressed: () async {
                  User? user = await AuthService().signInWithApple(context);
                  if (user != null) {
                    Navigator.pushReplacementNamed(context, '/create_lesson');
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
