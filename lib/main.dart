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
import 'screens/custom_lesson_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_navigation_screen.dart';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'theme/theme.dart';
import 'utils/constants.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:parakeet/services/notification_service.dart';
import 'package:parakeet/services/background_audio_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/onboarding_form_screen.dart';
import 'screens/all_words_screen.dart';

const bool versionForTestFlight = true;
const String localShouldUpdateID = "gWYwwwYY";
const String localCouldUpdateID = "d*h&f%0a";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize MobileAds on mobile platforms
  // if (!kIsWeb) {
  //   MobileAds.instance.initialize();
  //   // Initialize AdService to preload first ad
  //   await AdService.initialize();
  // }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initialize();

  // Initialize background audio service
  await BackgroundAudioService.initialize();

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
    final String? firebaseShouldUpdateID = data['should_update_app_ID'] as String?;
    final String? updateMessage = data['should_update_app_message'] as String?;

    if (firebaseShouldUpdateID == null || updateMessage == null || versionForTestFlight) {
      // Optionally log or handle missing fields
      return;
    }

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
              final appStoreUrl = Platform.isIOS ? urlIOS : urlAndroid;
              launchURL(appStoreUrl); // Redirect to App Store/Play Store
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

Future<String> _getInitialRoute() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData != null && (!userData.containsKey('onboarding_completed') || userData['onboarding_completed'] == false)) {
        return '/onboarding';
      }
    }
  }
  return '/custom_lesson';
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class ResponsiveScreenWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveScreenWrapper({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ResponsiveBreakpoints.of(context).largerThan(TABLET)
        ? Container(
            color: colorScheme.surfaceBright,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 350, // Mobile-like width for desktop views
                  height: 700,
                  child: child,
                ),
              ),
            ),
          )
        : child;
  }
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<PurchaseDetails>> _iapSubscription;
  late StreamSubscription<User?> _authSubscription;
  String? _initialRoute;

  bool _navigatingToOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _initialRoute = await _getInitialRoute();
    if (mounted) setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) await checkForMandatoryUpdate();
      if (!kIsWeb) await checkForRecommendedUpdate();
      if (!kIsWeb && (Platform.isIOS)) await requestTrackingPermission();
    });

    final Stream purchaseUpdated = InAppPurchase.instance.purchaseStream;

    _iapSubscription = purchaseUpdated.listen((purchaseDetailsList) {
      IAPService(context.read<AuthService>().currentUser!.uid).listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _iapSubscription.cancel();
    }, onError: (error) {
      _iapSubscription.cancel();
    }) as StreamSubscription<List<PurchaseDetails>>;

    // Monitor authentication state changes
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        // Add a small delay to avoid race condition with auth_service._initializeUserDocument
        await Future.delayed(const Duration(milliseconds: 500));

        if (_navigatingToOnboarding) return;

        // Check onboarding completion for newly logged-in users
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null && (!userData.containsKey('onboarding_completed') || userData['onboarding_completed'] == false)) {
            if (mounted) {
              setState(() {
                _navigatingToOnboarding = true;
              });
              Navigator.pushReplacementNamed(context, '/onboarding');
            }
            return;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _iapSubscription.cancel();
    _authSubscription.cancel();
    super.dispose();
  }

  Widget _buildAuthenticatedMainNavigation(String initialRoute) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
              if (snapshot.connectionState == ConnectionState.active) {
                if (snapshot.hasData) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
                    builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
                      if (userSnapshot.connectionState == ConnectionState.done) {
                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          if (!userData.containsKey('onboarding_completed') || userData['onboarding_completed'] == false) {
                            // Redirect to onboarding if not completed
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              Navigator.pushReplacementNamed(context, '/onboarding');
                            });
                            return const Center(child: CircularProgressIndicator());
                          }
                          return MainNavigationScreen(initialRoute: initialRoute);
                        }
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  );
                } else {
                  return const AuthScreen();
                }
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else {
                return const Center(child: Text('Failed to load'));
              }
            },
          ),
        );
      },
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (_initialRoute == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
        builder: (context, child) => ResponsiveBreakpoints.builder(
              child: child!,
              breakpoints: [
                const Breakpoint(start: 0, end: 599, name: MOBILE),
                const Breakpoint(start: 600, end: 1023, name: TABLET),
                const Breakpoint(start: 1024, end: 1920, name: DESKTOP),
                const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
              ],
            ),
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Parakeet',
        theme: AppTheme.dark,
        initialRoute: _initialRoute,
        onGenerateRoute: (RouteSettings settings) {
          WidgetBuilder builder;
          switch (settings.name) {
            case '/onboarding':
              builder = (context) => ResponsiveScreenWrapper(
                    child: WillPopScope(
                      onWillPop: () async => false, // Prevent navigation back
                      child: const OnboardingScreen(),
                    ),
                  );
              break;
            case '/onboarding_form':
              builder = (context) => ResponsiveScreenWrapper(
                    child: WillPopScope(
                      onWillPop: () async => false, // Prevent navigation back
                      child: const OnboardingFormScreen(),
                    ),
                  );
              break;
            case '/create_lesson':
              builder = (context) => ResponsiveScreenWrapper(
                    child: _buildAuthenticatedMainNavigation('/create_lesson'),
                  );
              break;
            case '/custom_lesson':
              builder = (context) => ResponsiveScreenWrapper(
                    child: _buildAuthenticatedMainNavigation('/custom_lesson'),
                  );
              break;
            case '/favorite':
              builder = (context) => ResponsiveScreenWrapper(
                    child: _buildAuthenticatedMainNavigation('/favorite'),
                  );
              break;
            case '/vocabulary_review':
              builder = (context) => ResponsiveScreenWrapper(
                    child: _buildAuthenticatedMainNavigation('/vocabulary_review'),
                  );
              break;
            case '/all_words':
              builder = (context) => const ResponsiveScreenWrapper(
                    child: AllWordsScreen(),
                  );
              break;
            case '/login':
              builder = (context) => const ResponsiveScreenWrapper(
                    child: AuthScreen(),
                  );
              break;
            case '/profile':
              builder = (context) => ResponsiveScreenWrapper(
                    child: ChangeNotifierProvider(
                      create: (context) => HomeScreenModel(),
                      child: const ProfileScreen(),
                    ),
                  );
              break;
            default:
              return null;
          }

          return PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => builder(context),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          );
        });
  }
}
