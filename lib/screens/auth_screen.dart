import 'package:parakeet/services/auth_service.dart';
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
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  User? user = await AuthService().signInWithGoogle();
                  if (user != null) {
                    DocumentReference userDocRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid);
                    DocumentSnapshot userDocSnapshot = await userDocRef.get();
                    if (!userDocSnapshot.exists) {
                      await userDocRef.set({
                        'name': user.displayName,
                        'email': user.email,
                        // Add more user data as needed
                      });
                    }

                    Navigator.pop(context); // Hide loading indicator
                    Navigator.pushReplacementNamed(context, '/');
                  } else {
                    Navigator.pop(context); // Hide loading indicator
                    // Handle the case where the user is null
                  }
                } catch (e) {
                  Navigator.pop(context); // Hide loading indicator
                  // Handle errors, possibly show an error dialog
                }
              },
              child: const Text('Sign In with Google'),
            )
          ],
        ),
      ),
    );
  }
}
