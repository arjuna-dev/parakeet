import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:parakeet/screens/profile_screen.dart';
import 'package:parakeet/services/auth_service.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/services/iap_service.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'screens/create_lesson_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/library_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  await requestTrackingPermission();
}

Future<void> requestTrackingPermission() async {
  // Check if the tracking status has not been determined
  if (await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
    // Show an explainer dialog before the ATT prompt
    await showCustomTrackingDialog();

    // Wait a moment before presenting the ATT prompt
    await Future.delayed(const Duration(milliseconds: 200));

    // Request tracking authorization
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}

// Method to display the custom explainer dialog
Future<void> showCustomTrackingDialog() async {
  return showDialog<void>(
    context: navigatorKey.currentContext!,
    barrierDismissible: false, // User must explicitly interact with dialog
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(
          'Hi, there! 👋',
          style: TextStyle(
            fontSize: 24, // Increase font size
            fontWeight: FontWeight.bold, // Make text bold
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We kindly ask you to allow use of tracking data.\n\nYour permission helps us deliver a better and even more tailored experience!',
              style: TextStyle(
                fontSize: 18, // Increase font size for content
                fontWeight: FontWeight.bold, // Make text bold
              ),
            ),
            SizedBox(height: 10), // Add some spacing before the emoji line
            Center(
              child: Text(
                '🤗',
                style: TextStyle(
                  fontSize: 40, // Make the emoji larger
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Continue'),
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
          ),
        ],
      );
    },
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
      IAPService(context.read<AuthService>().currentUser!.uid).listenToPurchaseUpdated(purchaseDetailsList);
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
      navigatorKey: navigatorKey,
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
              builder: (context) => const CreateLesson(title: 'Create an audio lesson'),
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
