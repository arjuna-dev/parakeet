import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/homepage.dart';
import 'screens/auth_screen.dart';
import 'screens/search_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parakeet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.data == null) {
                    // If the user is not logged in, redirect to AuthScreen
                    return const AuthScreen();
                  } else {
                    // If the user is logged in, show the Home page
                    return const HomePage(title: 'Parakeet Home page');
                  }
                }

                // While the connection state is not active, show a loading spinner
                return const CircularProgressIndicator();
              },
            ),
        '/login': (context) => const AuthScreen(),
        '/search': (context) => const SearchScreen(),
      },
    );
  }
}
