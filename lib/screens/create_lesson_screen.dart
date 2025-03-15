import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/language_categories.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/category_list.dart';
import 'package:parakeet/widgets/custom_lesson_form.dart';

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

  List<Map<String, dynamic>> get categories => getCategoriesForLanguage(targetLanguage);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserPreferences();
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
        actions: <Widget>[
          buildProfilePopupMenu(context),
        ],
      ),
      body: Column(
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
                  nativeLanguage: nativeLanguage,
                  targetLanguage: targetLanguage,
                  languageLevel: languageLevel,
                  isSmallScreen: isSmallScreen,
                ),

                // Custom Lesson Tab
                CustomLessonForm(
                  nativeLanguage: nativeLanguage,
                  targetLanguage: targetLanguage,
                  languageLevel: languageLevel,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
    );
  }
}
