import 'package:auralearn/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/create_lesson_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/library_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider(
      create: (context) => HomeScreenModel(),
      child: const MyApp(),
    ),
  );
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
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
                  if (snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.data == null) {
                      // If the user is not logged in, redirect to AuthScreen
                      return const AuthScreen();
                    } else {
                      // If the user is logged in, show the Home page
                      return ChangeNotifierProvider(
                        create: (context) => HomeScreenModel(),
                        child: const Home(),
                      );
                    }
                  }

                  // While the connection state is not active, show a loading spinner
                  return const CircularProgressIndicator();
                },
              ),
            );
          case '/create_lesson':
            return MaterialPageRoute(
              builder: (context) =>
                  const CreateLesson(title: 'Parakeet'),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (context) => const AuthScreen(),
            );
          case '/library':
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (context) => HomeScreenModel(),
                child: const Library(),
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}
