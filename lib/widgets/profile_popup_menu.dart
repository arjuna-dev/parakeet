import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

Widget buildProfilePopupMenu(BuildContext context) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.account_circle),
    onSelected: (String result) async {
      switch (result) {
        case 'Profile':
          Navigator.pushNamed(context, '/profile');
          break;
        case 'Logout':
          await FirebaseAuth.instance.signOut();
          await FirebaseAnalytics.instance.logEvent(name: 'logout');
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          break;
      }
    },
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'Profile',
        child: Text('Profile'),
      ),
      const PopupMenuItem<String>(
        value: 'Logout',
        child: Text('Logout'),
      ),
    ],
  );
}
