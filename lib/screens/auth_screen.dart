import 'package:auralearn/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
                // Sign in with Google
                User? user = await AuthService().signInWithGoogle();
                if (user != null) {
                  // Store user to Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                    'name': user.displayName,
                    'email': user.email,
                    // Add more user data as needed
                  });

                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              child: const Text('Sign In with Google'),
            ),
          ],
        ),
      ),
    );
  }
}
