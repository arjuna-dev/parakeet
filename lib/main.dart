import 'dart:async';
import 'dart:io';
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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/create_lesson_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/library_screen.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
const String localShouldUpdateID = "bRj98tXx";
const String localCouldUpdateID = "d*h&f%0a";

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

Future<void> checkForMandatoryUpdate() async {
  final firestore = FirebaseFirestore.instance;
  final docRef = firestore.collection('should_update_app').doc('6h9D0BVJ9BSsbRj98tXx');

  final docSnapshot = await docRef.get();

  if (docSnapshot.exists) {
    final data = docSnapshot.data() as Map<String, dynamic>;
    final String firebaseShouldUpdateID = data['should_update_app_ID'];
    final String updateMessage = data['should_update_app_message'];

    if (firebaseShouldUpdateID != localShouldUpdateID) {
      _showUpdateDialog(updateMessage, true);
    }
  }
}

Future<void> checkForRecommendedUpdate() async {
  final firestore = FirebaseFirestore.instance;
  final docRef = firestore.collection('should_update_app').doc('6h9D0BVJ9BSsbRj98tXx');

  final docSnapshot = await docRef.get();

  if (docSnapshot.exists) {
    final data = docSnapshot.data() as Map<String, dynamic>;
    final String firebaseCouldUpdateID = data['could_update_app_ID'];
    final String updateMessage = data['could_update_app_message'];

    if (firebaseCouldUpdateID != localCouldUpdateID) {
      _showUpdateDialog(updateMessage, false);
    }
  }
}

final Uri _url_iOS = Uri.parse('https://apps.apple.com/app/6618158139');
final Uri _url_android = Uri.parse('https://play.google.com/store/apps/details?id=com.parakeetapp.app');

void _showUpdateDialog(String message, bool brickApp) {
  showDialog(
    context: navigatorKey.currentContext!,
    barrierDismissible: false, // Prevent dialog dismissal
    builder: (BuildContext context) {
      return AlertDialog(
        title: brickApp ? const Text('Update Required') : const Text('Update Available'),
        content: Text(
          message, // Display message from Firebase
          style: const TextStyle(
            fontSize: 18, // Set a larger font size
            fontWeight: FontWeight.bold, // Make the text bold
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Update'),
            onPressed: () {
              final appStoreUrl = Platform.isIOS ? _url_iOS : _url_android;
              _launchURL(appStoreUrl); // Redirect to App Store/Play Store
            },
          ),
          TextButton(
            child: brickApp ? const Text('Close App') : const Text('Continue'),
            onPressed: () {
              if (brickApp) {
                exit(0); // Close the app
              } else {
                // Close the dialog
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      );
    },
  );
}

void _launchURL(Uri url) async {
  if (await canLaunchUrl(url)) {
    await launchUrl(url);
  } else {
    throw 'Could not launch $url';
  }
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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) await checkForMandatoryUpdate();
      if (!kIsWeb) await checkForRecommendedUpdate();
      if (Platform.isIOS) await requestTrackingPermission();
      
    });

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
      initialRoute: '/create_lesson',
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/create_lesson':
            return MaterialPageRoute(
              builder: (context) => StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
                  if (snapshot.connectionState == ConnectionState.active) {
                    if (snapshot.data == null) {
                      return const AuthScreen();
                    } else {
                      return const CreateLesson(title: 'Create an audio lesson');
                    }
                  }
                  return const CircularProgressIndicator();
                },
              ),
            );
          case '/favorite':
            return MaterialPageRoute(
              builder: (context) => ChangeNotifierProvider(
                create: (context) => HomeScreenModel(),
                child: const Home(),
              ),
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
