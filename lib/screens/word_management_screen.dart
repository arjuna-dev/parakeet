import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/utils/script_generator.dart' show get5MostOverdueWordsRefs, getDocsAndRefsMaps;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart' show WordCard;
import 'package:parakeet/widgets/home_screen/empty_state_view.dart';
import 'package:parakeet/widgets/home_screen/tab_content_view.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/widgets/audio_player_screen/review_words_dialog.dart';
import 'package:parakeet/screens/category_detail_screen.dart' show WordProgressBar, showCenteredToast;
import 'package:parakeet/utils/language_categories.dart';

class WordManagementScreen extends StatefulWidget {
  final String? nativeLanguage;

  const WordManagementScreen({
    Key? key,
    this.nativeLanguage,
  }) : super(key: key);

  @override
  State<WordManagementScreen> createState() => _WordManagementScreenState();
}

class _WordManagementScreenState extends State<WordManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late bool _isLoadingAll;
  late bool _isLoadingDue;
  late String _userId;
  late String _targetLanguage;
  late String _nativeLanguage;

  // Categories for both languages
  late List<Map<String, dynamic>> _targetLanguageCategories;
  late List<Map<String, dynamic>> _nativeLanguageCategories;

  final List<WordCard> _allWordsFull = [];
  final List<WordCard> _dueWordsFull = [];
  final Map<String, DocumentReference> _dueWordsRefs = {};

  int _allPage = 0;
  int _duePage = 0;
  static const int _pageSize = 20;

  // Track which tab is selected to show/hide the Review button
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isLoadingAll = true;
    _isLoadingDue = true;
    _initializeData();

    // Add listener to update state when tab changes
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  Future<void> _initializeData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userId = user.uid;
    final userData = await ProfileService.fetchUserData();
    _targetLanguage = userData['target_language'] as String? ?? '';
    _nativeLanguage = widget.nativeLanguage ?? userData['native_language'] as String? ?? 'English (US)';

    // Load categories for both languages
    _targetLanguageCategories = getCategoriesForLanguage(_targetLanguage);
    _nativeLanguageCategories = getCategoriesForLanguage(_nativeLanguage);

    await _loadAllWords();
    await _loadDueWords();
  }

  Future<void> _loadAllWords() async {
    setState(() => _isLoadingAll = true);
    final categoriesRef = FirebaseFirestore.instance.collection('users').doc(_userId).collection('${_targetLanguage}_words');
    final categories = await categoriesRef.get();
    final refs = <DocumentReference>[];
    for (var cat in categories.docs) {
      final wordsCol = categoriesRef.doc(cat.id).collection(cat.id);
      final snap = await wordsCol.get();
      for (var doc in snap.docs) {
        refs.add(doc.reference);
      }
    }
    final maps = await getDocsAndRefsMaps(refs);
    final docs = maps['docs'] as List<Map<String, dynamic>>;

    // Convert to WordCard objects first for easier sorting
    final wordCards = docs.map(WordCard.fromFirestore).toList(); // Sort words by learning status and then alphabetically within each group
    wordCards.sort((a, b) {
      // Get status flags for word A
      final scheduledDaysA = a.card.scheduledDays.toDouble();
      final learningA = a.card.reps > 0;
      final isMasteredA = scheduledDaysA >= 100;

      // Get status flags for word B
      final scheduledDaysB = b.card.scheduledDays.toDouble();
      final learningB = b.card.reps > 0;
      final isMasteredB = scheduledDaysB >= 100;

      // Assign category values for sorting priority:
      // 0: Learning (has reps but not mastered)
      // 1: Not Started (no reps)
      // 2: Mastered
      int categoryA;
      int categoryB;

      if (learningA && !isMasteredA) {
        categoryA = 0; // Learning
      } else if (!learningA) {
        categoryA = 1; // Not started
      } else {
        categoryA = 2; // Mastered
      }

      if (learningB && !isMasteredB) {
        categoryB = 0; // Learning
      } else if (!learningB) {
        categoryB = 1; // Not started
      } else {
        categoryB = 2; // Mastered
      }

      // Sort by category first
      if (categoryA != categoryB) {
        return categoryA.compareTo(categoryB);
      }

      // Same status, sort alphabetically
      return a.word.compareTo(b.word);
    });

    setState(() {
      _allWordsFull
        ..clear()
        ..addAll(wordCards);
      _isLoadingAll = false;
    });
  }

  Future<void> _loadDueWords() async {
    setState(() => _isLoadingDue = true);
    final refs = await get5MostOverdueWordsRefs(_userId, _targetLanguage, []);
    final maps = await getDocsAndRefsMaps(refs);
    final docs = maps['docs'] as List<Map<String, dynamic>>;
    final refsMap = maps['refsMap'] as Map<String, DocumentReference>;

    // Convert to WordCard objects first for easier sorting
    final wordCards = docs.map(WordCard.fromFirestore).toList();

    // Sort words by learning status and then alphabetically within each group
    wordCards.sort((a, b) {
      // Get status flags for word A
      final scheduledDaysA = a.card.scheduledDays.toDouble();
      final learningA = a.card.reps > 0;
      final isLearnedA = scheduledDaysA >= 80;
      final isMasteredA = scheduledDaysA >= 100;

      // Get status flags for word B
      final scheduledDaysB = b.card.scheduledDays.toDouble();
      final learningB = b.card.reps > 0;
      final isLearnedB = scheduledDaysB >= 80;
      final isMasteredB = scheduledDaysB >= 100;

      // Define categories for sorting
      int categoryA = 0;
      int categoryB = 0;

      // Category 0: Learning (has reps but not mastered)
      // Category 1: Not Started (no reps)
      // Category 2: Mastered

      if (learningA && !isMasteredA)
        categoryA = 0;
      else if (!learningA)
        categoryA = 1;
      else if (isMasteredA) categoryA = 2;

      if (learningB && !isMasteredB)
        categoryB = 0;
      else if (!learningB)
        categoryB = 1;
      else if (isMasteredB) categoryB = 2;

      // Sort by category first
      if (categoryA != categoryB) {
        return categoryA.compareTo(categoryB);
      }

      // Same status, sort alphabetically
      return a.word.compareTo(b.word);
    });

    setState(() {
      _dueWordsFull
        ..clear()
        ..addAll(wordCards);
      _dueWordsRefs
        ..clear()
        ..addAll(refsMap);
      _isLoadingDue = false;
    });
  }

  // Method to find word translation by looking up the category and index
  String findWordTranslation(String word) {
    // Find the category and index of the word in target language
    for (final targetCategory in _targetLanguageCategories) {
      final List<dynamic> words = targetCategory['words'];
      final int wordIndex = words.indexWhere((w) => w.toLowerCase() == word.toLowerCase());

      if (wordIndex != -1) {
        // Found the word, now find matching category in native language
        final String categoryName = targetCategory['name'];

        // Find the matching category in native language categories with Map<String, Object> return type
        // This is important for type safety with FirestoreObject compatibility
        final Map<String, Object> emptyCategory = <String, Object>{'words': <Object>[]};
        final matchingNativeCategory = _nativeLanguageCategories.firstWhere((natCat) => natCat['name'] == categoryName, orElse: () => emptyCategory);

        // Get the translation at the same index if available
        final List<dynamic> nativeWords = matchingNativeCategory['words'] as List<dynamic>;
        if (nativeWords.isNotEmpty && wordIndex < nativeWords.length) {
          return "${nativeWords[wordIndex]}";
        }
      }
    }

    // If word not found in any category or matching translation not found
    return word;
  }

  // Helper method to show translated word in toast
  void _showTranslatedWordToast(BuildContext context, String word) {
    showCenteredToast(context, findWordTranslation(word));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Word Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
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
            Tab(text: 'Due Words'),
            Tab(text: 'All Words'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Tab content in an Expanded widget to take available space
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                TabContentView(
                  isSmallScreen: isSmallScreen,
                  child: _buildDueWordsTab(isSmallScreen, colorScheme),
                ),
                TabContentView(
                  isSmallScreen: isSmallScreen,
                  child: _buildAllWordsTab(isSmallScreen, colorScheme),
                ),
              ],
            ),
          ),
          // Review button outside the TabContentView when on Due Words tab
          if (_currentTabIndex == 0 && !_isLoadingDue && _dueWordsFull.isNotEmpty)
            SizedBox(
              width: double.infinity, // Makes the button take full width
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12), // Added more vertical padding
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  minimumSize: const Size(double.infinity, 0), // Ensures button expands horizontally
                ),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (BuildContext context) {
                      final colorScheme = Theme.of(context).colorScheme;
                      return SafeArea(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Modal header
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Review Options',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Audio Review Option
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.headset,
                                            size: 24,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Audio Review',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'A simple review of the words you need to review with audio support',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // New Lesson Option
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.pushReplacementNamed(context, '/create_lesson');
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.school,
                                            size: 24,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'New Lesson',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Create a new lesson with more context, new words and review overdue words',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Card Review Option
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pop();
                                  showDialog(
                                    context: context,
                                    builder: (context) => ReviewWordsDialog(
                                      words: _dueWordsRefs,
                                      userID: _userId,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceVariant.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.primary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.style,
                                            size: 24,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Card Review',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'A simple visual review where you test and rate your memory',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Review'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: '/word_management'),
    );
  }

  Widget _buildAllWordsTab(bool isSmallScreen, ColorScheme colorScheme) {
    if (_isLoadingAll) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_allWordsFull.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              children: [
                const TextSpan(text: "Nothing to see here yet! Head to the ", style: TextStyle(fontStyle: FontStyle.italic)),
                TextSpan(
                  text: 'create lesson tab',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacementNamed(context, '/create_lesson');
                    },
                ),
                const TextSpan(text: ' to start your learning journey!', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ),
      );
    }
    final displayed = _allWordsFull.take((_allPage + 1) * _pageSize).toList();
    const int crossAxisCount = 2;
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are words you have started learning.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(0),
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
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(0.5, -0.5),
                        radius: 1.2,
                        colors: [
                          colorScheme.primary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayed.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                          child: Text(
                            'Tap any word to see its translation',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.2, // Making cards even taller
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: displayed.length,
                          itemBuilder: (context, index) {
                            final card = displayed[index];
                            final scheduledDays = card.card.scheduledDays.toDouble();
                            final learning = card.card.reps > 0;
                            final isLearned = scheduledDays >= 80;
                            final isMastered = scheduledDays >= 100;
                            return InkWell(
                              onTap: () => _showTranslatedWordToast(context, card.word),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isLearned ? const Color.fromARGB(255, 136, 225, 139).withOpacity(0.5) : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Increased vertical padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min, // Using mainAxisSize.min instead of center alignment
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            card.word,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMastered) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Color.fromARGB(255, 136, 225, 139),
                                          ),
                                        ] else if (isLearned) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Color.fromARGB(255, 136, 225, 139),
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      () {
                                        if (isMastered) return 'Mastered';
                                        if (isLearned) return 'Learned';
                                        if (learning) return 'Learning';
                                        return 'Not started';
                                      }(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: () {
                                          if (isMastered) {
                                            return const Color.fromARGB(255, 136, 225, 139);
                                          }
                                          if (isLearned) {
                                            return const Color.fromARGB(255, 136, 225, 139).withOpacity(0.8);
                                          }
                                          if (learning) {
                                            return Colors.amber;
                                          }
                                          return Colors.white.withOpacity(0.6);
                                        }(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    WordProgressBar(score: scheduledDays),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${scheduledDays.toInt()} days until next review',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (displayed.length < _allWordsFull.length)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                          child: Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _allPage++;
                                });
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Show More',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDueWordsTab(bool isSmallScreen, ColorScheme colorScheme) {
    if (_isLoadingDue) {
      return const Center(child: CircularProgressIndicator());
    }
    final displayed = _dueWordsFull.take((_duePage + 1) * _pageSize).toList();
    const int crossAxisCount = 2;
    if (_dueWordsFull.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              children: [
                const TextSpan(text: 'You are up to speed with your learning! To continue on your journey ', style: TextStyle(fontStyle: FontStyle.italic)),
                TextSpan(
                  text: 'create a new lesson',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    //make italics
                    fontStyle: FontStyle.italic,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () {
                      Navigator.pushReplacementNamed(context, '/create_lesson');
                    },
                )
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are words due for review based on our advanced FSRS algorithm.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: isSmallScreen ? 14 : 16,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(1),
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
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: RadialGradient(
                        center: const Alignment(0.5, -0.5),
                        radius: 1.2,
                        colors: [
                          colorScheme.primary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (displayed.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                          child: Text(
                            'Tap any word to see its translation',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 1.2, // Making cards even taller
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: displayed.length,
                          itemBuilder: (context, index) {
                            final card = displayed[index];
                            final scheduledDays = card.card.scheduledDays.toDouble();
                            final learning = card.card.reps > 0;
                            final isLearned = scheduledDays >= 80;
                            final isMastered = scheduledDays >= 100;
                            return InkWell(
                              onTap: () => _showTranslatedWordToast(context, card.word),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isLearned ? const Color.fromARGB(255, 136, 225, 139).withOpacity(0.5) : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Increased vertical padding
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min, // Using mainAxisSize.min instead of center alignment
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            card.word,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isMastered) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.star,
                                            size: 14,
                                            color: Color.fromARGB(255, 136, 225, 139),
                                          ),
                                        ] else if (isLearned) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: Color.fromARGB(255, 136, 225, 139),
                                          ),
                                        ]
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      () {
                                        if (isMastered) return 'Mastered';
                                        if (isLearned) return 'Learned';
                                        if (learning) return 'Learning';
                                        return 'Not started';
                                      }(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: () {
                                          if (isMastered) {
                                            return const Color.fromARGB(255, 136, 225, 139);
                                          }
                                          if (isLearned) {
                                            return const Color.fromARGB(255, 136, 225, 139).withOpacity(0.8);
                                          }
                                          if (learning) {
                                            return Colors.amber;
                                          }
                                          return Colors.white.withOpacity(0.6);
                                        }(),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    WordProgressBar(score: scheduledDays),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${scheduledDays.toInt()} days until next review',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (displayed.length < _dueWordsFull.length)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
                          child: Center(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _duePage++;
                                });
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Show More',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.expand_more,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // SizedBox(
        //   width: double.infinity,
        //   child:
        // ),
      ],
    );
  }
}
