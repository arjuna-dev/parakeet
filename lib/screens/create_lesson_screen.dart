import 'package:flutter/material.dart';
import 'package:parakeet/utils/language_categories.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/create_lesson_screen/category_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';
  bool _isPremiumUser = false;
  bool _isLoading = true;

  List<Map<String, dynamic>> get categories => getCategoriesForLanguage(targetLanguage);
  List<Map<String, dynamic>> get nativeCategories => getCategoriesForLanguage(nativeLanguage);

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _checkPremiumStatus();
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
    return Scaffold(
      appBar: AppBarWithDrawer(
        title: widget.title!,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CategoryList(
              categories: categories,
              nativeCategories: nativeCategories,
              nativeLanguage: nativeLanguage,
              targetLanguage: targetLanguage,
              languageLevel: languageLevel,
              isPremiumUser: _isPremiumUser,
            ),
    );
  }
}
