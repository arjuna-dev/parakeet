import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/language_categories.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/create_lesson_screen/category_list.dart';
import 'package:parakeet/widgets/home_screen/custom_lesson_form.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> with SingleTickerProviderStateMixin {
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';
  late TabController _tabController;
  bool _isPremiumUser = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> get categories => getCategoriesForLanguage(targetLanguage);
  List<Map<String, dynamic>> get nativeCategories => getCategoriesForLanguage(nativeLanguage);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserPreferences();
    _checkPremiumStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when navigated back to this screen
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _loadUserPreferences();
      _checkPremiumStatus();
    }
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final isPremium = userDoc.data()?['premium'] ?? false;

        setState(() {
          _isPremiumUser = isPremium;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isPremiumUser = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking premium status: $e');
      setState(() {
        _isPremiumUser = false;
        _isLoading = false;
      });
    }
  }

  void _loadUserPreferences() async {
    try {
      final settings = await UserService.getUserLanguageSettings();
      setState(() {
        nativeLanguage = settings['nativeLanguage']!;
        targetLanguage = settings['targetLanguage']!;
        languageLevel = settings['languageLevel']!;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title!,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Bar
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: colorScheme.primary,
                    indicatorWeight: 3,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.category),
                        text: 'Categories',
                      ),
                      Tab(
                        icon: Icon(Icons.create),
                        text: 'Custom Lesson',
                      ),
                    ],
                  ),
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Categories Tab
                      CategoryList(
                        categories: categories,
                        nativeCategories: nativeCategories,
                        nativeLanguage: nativeLanguage,
                        targetLanguage: targetLanguage,
                        languageLevel: languageLevel,
                        isPremiumUser: _isPremiumUser,
                      ),
                      // Custom Lesson Tab
                      CustomLessonForm(
                        nativeLanguage: nativeLanguage,
                        targetLanguage: targetLanguage,
                        languageLevel: languageLevel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: "/create_lesson"),
    );
  }
}
