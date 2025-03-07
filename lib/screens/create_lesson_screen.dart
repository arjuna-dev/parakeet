import 'package:parakeet/screens/lesson_detail_screen.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/activate_free_trial.dart';
import 'dart:convert';
import 'package:parakeet/utils/language_categories.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  final activeCreationAllowed = 20;
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';

  List<Map<String, dynamic>> get categories => getCategoriesForLanguage(targetLanguage);

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when navigated back to this screen
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _loadUserPreferences();
    }
  }

  void _loadUserPreferences() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef = firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          nativeLanguage = data['native_language'] ?? nativeLanguage;
          targetLanguage = data['target_language'] ?? targetLanguage;
          languageLevel = data['language_level'] ?? languageLevel;
        });
      }
    } catch (e) {
      print('Error fetching user preferences: $e');
    }
  }

  Future<int> countUsersInActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('users')) {
          final users = data['users'] as List;
          return users.length;
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching users from active_creation: $e');
      return -1;
    }
  }

  Future<int> countAPIcallsByUser() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference userDocRef = firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid.toString()).collection('api_call_count').doc('first_API_calls');

    try {
      final DocumentSnapshot doc = await userDocRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('call_count') && data['last_call_date'] == "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}") {
          return data['call_count'];
        }
      }
      return 0;
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
      return -1;
    }
  }

  int getAPICallLimit(bool isPremium) {
    return isPremium ? 15 : 5;
  }

  Future<void> _handleCategorySelection(Map<String, dynamic> category) async {
    // Check premium status
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();
    final isPremium = userDoc.data()?['premium'] ?? false;
    final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

    if (!isPremium) {
      final apiCalls = await countAPIcallsByUser();
      if (apiCalls >= 5) {
        final shouldEnablePremium = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Generate up to 15 lessons per day'),
              content: const Text('You\'ve reached the free limit. Activate premium mode!!'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('No, thanks'),
                ),
                TextButton(
                  onPressed: () async {
                    final success = await activateFreeTrial(context, FirebaseAuth.instance.currentUser!.uid);
                    if (success) {
                      Navigator.pop(context, true);
                    } else {
                      Navigator.pop(context, false);
                    }
                  },
                  child: Text(hasUsedTrial ? 'Get premium for 1 month' : 'Try out free for 30 days'),
                ),
              ],
            );
          },
        );

        if (shouldEnablePremium != true) {
          Navigator.pushReplacementNamed(context, '/create_lesson');
          return;
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    var usersInActiveCreation = await countUsersInActiveCreation();
    if (usersInActiveCreation != -1 && usersInActiveCreation > activeCreationAllowed) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Too many users are creating lessons right now. Please try again in a moment.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    var apiCallsByUser = await countAPIcallsByUser();
    if (apiCallsByUser != -1 && apiCallsByUser >= getAPICallLimit(isPremium)) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPremium ? 'Unfortunately, you have reached the maximum number of creation for today 🙃. Please try again tomorrow.' : 'You\'ve reached the free limit. Upgrade to premium for more lessons!'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "category": category['name'],
          "allWords": category['words'],
          "target_language": targetLanguage,
          "native_language": nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        Navigator.pop(context);

        // Reset any static state in LessonDetailScreen before navigation
        LessonDetailScreen.resetStaticState();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LessonDetailScreen(
              title: result['title'] as String,
              topic: result['topic'] as String,
              wordsToLearn: (result['words_to_learn'] as List).cast<String>(),
              languageLevel: languageLevel,
              length: '4',
              nativeLanguage: nativeLanguage,
              targetLanguage: targetLanguage,
            ),
          ),
        );
      } else {
        throw Exception('Failed to generate lesson topic');
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isSmallScreen || kIsWeb ? 48.0 : 56.0),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.title!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen || kIsWeb ? 18 : 20,
            ),
          ),
          actions: <Widget>[
            buildProfilePopupMenu(context),
          ],
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isSmallScreen ? 8 : 16,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => _handleCategorySelection(category),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getCategoryIcon(category['name'] as String),
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category['name'] as String,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(category['words'] as List).length} words',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 13 : 14,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: colorScheme.onSurfaceVariant,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'At the Coffee Shop':
        return Icons.coffee;
      case 'Weather Talk':
        return Icons.wb_sunny;
      case 'In the Supermarket':
        return Icons.shopping_cart;
      case 'Asking for Directions':
        return Icons.map;
      case 'Making Small Talk':
        return Icons.chat_bubble;
      case 'At the Airport':
        return Icons.flight;
      case 'At the Restaurant':
        return Icons.restaurant;
      case 'At the Hotel':
        return Icons.hotel;
      case 'At the Doctor\'s Office':
        return Icons.local_hospital;
      case 'Public Transportation':
        return Icons.directions_bus;
      case 'Shopping for Clothes':
        return Icons.shopping_bag;
      case 'At the Gym':
        return Icons.fitness_center;
      case 'At the Bank':
        return Icons.account_balance;
      case 'At the Post Office':
        return Icons.local_post_office;
      case 'At the Pharmacy':
        return Icons.local_pharmacy;
      case 'At the Park':
        return Icons.park;
      case 'At the Beach':
        return Icons.beach_access;
      case 'At the Library':
        return Icons.library_books;
      case 'At the Cinema':
        return Icons.movie;
      case 'At the Hair Salon':
        return Icons.content_cut;
      default:
        return Icons.category;
    }
  }
}
