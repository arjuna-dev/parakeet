import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/nickname_popup.dart';

Widget buildProfilePopupMenu(BuildContext context) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.account_circle),
    onSelected: (String result) {
      switch (result) {
        case 'Profile':
          Navigator.pushNamed(context, '/profile');
          break;
        case 'Logout':
          FirebaseAuth.instance.signOut().then((value) {
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          });
          break;
        case 'Edit Name':
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return const NicknamePopup();
            },
          );
          break;
        case 'Language Settings':
          Navigator.pushNamed(context, '/profile'); // Navigate to profile screen where language settings are available
          break;
      }
    },
    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'Profile',
        child: Text('Profile'),
      ),
      const PopupMenuItem<String>(
        value: 'Edit Name',
        child: Text('Edit Name'),
      ),
      const PopupMenuItem<String>(
        value: 'Language Settings',
        child: Text('Language Settings'),
      ),
      const PopupMenuItem<String>(
        value: 'Logout',
        child: Text('Logout'),
      ),
    ],
  );
}
