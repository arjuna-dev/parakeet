import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:parakeet/services/iap_service.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/create_lesson_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/library_screen.dart';
import 'screens/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => HomeScreenModel()),
        Provider<AuthService>.value(value: AuthService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<PurchaseDetails>> _iapSubscription;

  @override
  void initState() {
    super.initState();
    final Stream purchaseUpdated = InAppPurchase.instance.purchaseStream;

    _iapSubscription = purchaseUpdated.listen((purchaseDetailsList) {
      print("Purchase stream started");
      IAPService(context.read<AuthService>().currentUser!.uid)
          .listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _iapSubscription.cancel();
    }, onError: (error) {
      _iapSubscription.cancel();
    }) as StreamSubscription<List<PurchaseDetails>>;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
                  const CreateLesson(title: 'Create an audio lesson'),
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
          case '/profile':
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (context) => HomeScreenModel(),
                child: const ProfileScreen(),
              ),
            );
          default:
            return null;
        }
      },
    );
  }
}
