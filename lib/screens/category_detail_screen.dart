import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:parakeet/utils/mark_as_mastered_modal.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/utils/lesson_constants.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/services/word_stats_service.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/widgets/home_screen/lesson_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:parakeet/utils/constants.dart';

// Global variable to track active toast
OverlayEntry? _activeToastEntry;

class CategoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final Map<String, dynamic> nativeCategory;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;

  const CategoryDetailScreen({
    Key? key,
    required this.category,
    required this.nativeCategory,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
  }) : super(key: key);

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final List<Map<String, dynamic>> _learningWords = [];
  final List<DocumentSnapshot> _categoryLessons = [];
  bool _isLoading = true;
  bool _isLoadingLessons = true;
  final bool _wordsExpanded = false;
  WordStats? _wordStats;
  String _currentTargetLanguage = '';
  bool _isGeneratingLesson = false;
  int _generationsRemaining = 0;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _currentTargetLanguage = widget.targetLanguage;
    _loadLearningWords();
    _loadWordStats();
    _loadCategoryLessons();
    _loadGenerationsRemaining();
  }

  @override
  void didUpdateWidget(CategoryDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if target language has changed
    if (widget.targetLanguage != _currentTargetLanguage) {
      _currentTargetLanguage = widget.targetLanguage;
      _learningWords.clear();
      _categoryLessons.clear();
      _wordStats = null;
      _loadLearningWords();
      _loadWordStats();
      _loadCategoryLessons();
      _loadGenerationsRemaining();
    }
  }

  Future<void> _loadCategoryLessons() async {
    setState(() => _isLoadingLessons = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

      final categoryLessons = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        String lessonCategory;
        if (data?.containsKey('category') == true && doc.get('category') != null && doc.get('category').toString().trim().isNotEmpty) {
          lessonCategory = doc.get('category');
        } else {
          lessonCategory = 'Custom Lesson';
        }
        return lessonCategory == widget.category['name'];
      }).toList();

      // Sort by timestamp (newest first)
      categoryLessons.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

      if (mounted) {
        setState(() {
          _categoryLessons.clear();
          _categoryLessons.addAll(categoryLessons);
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      print('Error loading category lessons: $e');
      setState(() => _isLoadingLessons = false);
    }
  }

  Future<void> _loadLearningWords() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collection('users').doc(userId).collection('${widget.targetLanguage}_words').doc(widget.category['name']).collection(widget.category['name']).get();

      final wordsData = snapshot.docs.map((doc) => Map<String, dynamic>.from(doc.data())).toList();
      if (mounted) {
        setState(() {
          _learningWords.addAll(wordsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading learning words: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadWordStats() async {
    try {
      final stats = await WordStatsService.getCategoryWordStats(
        widget.category['name'],
        widget.targetLanguage,
        widget.category['words'] ?? [],
      );

      if (mounted) {
        setState(() {
          _wordStats = stats;
        });
      }
    } catch (e) {
      print('Error loading word stats: $e');
    }
  }

  Future<void> _loadGenerationsRemaining() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Check premium status
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final isPremium = userDoc.data()?['premium'] ?? false;

        // Get API calls used today
        final apiCallsUsed = await LessonService.countAPIcallsByUser();

        if (mounted) {
          setState(() {
            _isPremium = isPremium;
            int limit = isPremium ? LessonService.premiumAPILimit : LessonService.freeAPILimit;
            _generationsRemaining = apiCallsUsed >= limit ? 0 : limit - apiCallsUsed;
          });
        }
      }
    } catch (e) {
      print('Error loading generations remaining: $e');
    }
  }

  void _showWordsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
              child: Column(
                children: [
                  // Modal header
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          LessonConstants.getCategoryIcon(widget.category['name']),
                          color: _getCategoryColor(widget.category['name']),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Practise Words',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Tap any word to see translation • Long press for options',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Column Headers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Word',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 64,
                            child: Text(
                              'Mastery',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Words List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: (widget.category['words'] as List).length,
                      itemBuilder: (context, index) {
                        final word = (widget.category['words'] as List)[index].toString();
                        final nativeWord = (widget.nativeCategory['words'] as List)[index].toString();
                        return _buildSimpleWordItem(word, nativeWord);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCreateNewLesson() async {
    setState(() {
      _isGeneratingLesson = true;
    });

    final canProceed = await LessonService.checkPremiumAndAPILimits(context);
    if (!canProceed) {
      setState(() {
        _isGeneratingLesson = false;
      });
      return;
    }

    try {
      // Step 1: Select words and generate lesson topic
      final selectedWords = await LessonService.selectWordsFromCategory(widget.category['name'], widget.category['words'], widget.targetLanguage);

      final response = await http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/generate_lesson_topic'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "category": widget.category['name'],
          "selectedWords": selectedWords,
          "target_language": widget.targetLanguage,
          "native_language": widget.nativeLanguage,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate lesson topic');
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final String title = result['title'] as String;
      final String topic = result['topic'] as String;

      // Step 2: Start the lesson generation and navigate immediately
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
      final String documentId = docRef.id;
      final String userId = FirebaseAuth.instance.currentUser!.uid.toString();
      final TTSProvider ttsProvider = widget.targetLanguage == 'Azerbaijani' ? TTSProvider.openAI : TTSProvider.googleTTS;

      // Create an empty script document ID
      DocumentReference scriptDocRef = firestore.collection('chatGPT_responses').doc(documentId).collection('script-$userId').doc();

      // Start the API call (don't wait for it)
      http.post(
        Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/first_API_calls'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "requested_scenario": topic,
          "category": widget.category['name'],
          "keywords": selectedWords,
          "native_language": widget.nativeLanguage,
          "target_language": widget.targetLanguage,
          "length": '4',
          "user_ID": userId,
          "language_level": widget.languageLevel,
          "document_id": documentId,
          "tts_provider": ttsProvider.value.toString(),
        }),
      );

      // Navigate immediately to AudioPlayerScreen - let it handle the loading state
      final navigationResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(
            category: widget.category['name'],
            dialogue: const [], // Start with empty dialogue, AudioPlayerScreen will load it
            title: title,
            documentID: documentId,
            userID: userId,
            scriptDocumentId: scriptDocRef.id,
            generating: true,
            targetLanguage: widget.targetLanguage,
            nativeLanguage: widget.nativeLanguage,
            languageLevel: widget.languageLevel,
            wordsToRepeat: selectedWords,
            numberOfTurns: 4,
          ),
        ),
      );

      // Refresh lessons when returning from AudioPlayerScreen
      if (navigationResult == 'reload') {
        _loadCategoryLessons();
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isGeneratingLesson = false;
      });
      // Refresh the generations count after attempting to create a lesson
      _loadGenerationsRemaining();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return ResponsiveScreenWrapper(
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.category['name'],
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Hero Section with Category Overview
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getCategoryColor(widget.category['name']).withOpacity(0.1),
                            _getCategoryColor(widget.category['name']).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getCategoryColor(widget.category['name']).withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Category Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LessonConstants.getCategoryIcon(widget.category['name']),
                              color: _getCategoryColor(widget.category['name']),
                              size: 48,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Category Title
                          Text(
                            widget.category['name'],
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 8),

                          // Progress Stats
                          if (_wordStats != null) ...[
                            const SizedBox(height: 20),
                            _buildModernProgressSection(),
                          ],

                          const SizedBox(height: 20),

                          // View Words Button
                          OutlinedButton(
                            onPressed: () => _showWordsModal(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _getCategoryColor(widget.category['name']),
                              side: BorderSide(
                                color: _getCategoryColor(widget.category['name']),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility_rounded,
                                  size: 18,
                                  color: _getCategoryColor(widget.category['name']),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'View All Words (${(widget.category['words'] as List).length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Generated Lessons Section
                    if (!_isLoadingLessons && _categoryLessons.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: _getCategoryColor(widget.category['name']),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Generated Lessons',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(widget.category['name']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_categoryLessons.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _getCategoryColor(widget.category['name']),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Lessons List
                            ...(_categoryLessons.take(3).map((lesson) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: LessonCard(
                                    audioFile: lesson,
                                    onReload: _loadCategoryLessons,
                                    isSmallScreen: isSmallScreen,
                                    showCategoryBadge: false,
                                  ),
                                ))),

                            // Show More Button
                            if (_categoryLessons.length > 3)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showAllLessonsModal(context),
                                    icon: Icon(
                                      Icons.expand_more,
                                      color: _getCategoryColor(widget.category['name']),
                                      size: 18,
                                    ),
                                    label: Text(
                                      'View All ${_categoryLessons.length} Lessons',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      side: BorderSide(
                                        color: _getCategoryColor(widget.category['name']),
                                        width: 1.5,
                                      ),
                                      backgroundColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 120), // Space for floating action button
                  ],
                ),
              ),

        // Generate Button positioned on the right
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 20, right: 4),
          child: FloatingActionButton.extended(
            onPressed: _isGeneratingLesson ? null : _handleCreateNewLesson,
            backgroundColor: _getCategoryColor(widget.category['name']),
            foregroundColor: Colors.white,
            elevation: 8,
            icon: _isGeneratingLesson
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 22),
            label: _isGeneratingLesson
                ? const Text(
                    'Generating...',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Generate Lesson',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$_generationsRemaining remaining',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildModernProgressSection() {
    if (_wordStats == null) return const SizedBox.shrink();

    final totalWords = (widget.category['words'] as List).length;
    final masteredPercentage = totalWords > 0 ? (_wordStats!.mastered / totalWords * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getCategoryColor(widget.category['name']).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCategoryColor(widget.category['name']).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Progress Ring
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProgressStat('Mastered', _wordStats!.mastered, Theme.of(context).colorScheme.onSurface),
              _buildProgressStat('Learning', _wordStats!.learning, Theme.of(context).colorScheme.onSurfaceVariant),
              _buildProgressStat('New', totalWords - _wordStats!.mastered - _wordStats!.learning - _wordStats!.learned, Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: masteredPercentage / 100,
              minHeight: 8,
              backgroundColor: _getCategoryColor(widget.category['name']).withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(_getCategoryColor(widget.category['name'])),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            '$masteredPercentage% Complete',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModernWordsGrid() {
    final allWords = (widget.category['words'] as List).toList();
    final sortedWords = _getSortedWords(allWords);
    final displayWords = _wordsExpanded ? sortedWords : sortedWords.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: displayWords.length,
      itemBuilder: (context, index) {
        final wordData = displayWords[index];
        final word = wordData['word'] as String;
        final originalIndex = wordData['index'] as int;
        final nativeWord = (widget.nativeCategory['words'] as List)[originalIndex].toString();

        return _buildModernWordCard(word, nativeWord);
      },
    );
  }

  Widget _buildSimpleWordItem(String word, String nativeWord) {
    final colorScheme = Theme.of(context).colorScheme;
    final matching = _learningWords.firstWhere(
      (element) => element['word'] == word.toLowerCase(),
      orElse: () => {},
    );

    final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
    final reps = matching.isEmpty ? 0 : (matching['reps'] ?? 0);

    final isMastered = scheduledDays >= 100 || scheduledDays == -1;
    final isLearned = scheduledDays >= 80 && scheduledDays != -1;
    final isLearning = !isMastered && !isLearned && reps > 0;

    // Calculate progress percentage
    double progressValue;
    Color progressColor;

    if (isMastered) {
      progressValue = 1.0;
      progressColor = Colors.green;
    } else if (isLearned) {
      progressValue = 0.8;
      progressColor = Colors.blue;
    } else if (isLearning) {
      progressValue = scheduledDays / 100;
      progressColor = Colors.orange;
    } else {
      progressValue = 0.0;
      progressColor = colorScheme.onSurfaceVariant.withOpacity(0.3);
    }

    return InkWell(
      onTap: () => _showTranslationSheet(context, word, nativeWord),
      onLongPress: () => showMarkAsMasteredModal(
        context: context,
        word: word,
        categoryName: widget.category['name'],
        targetLanguage: widget.targetLanguage,
        learningWords: _learningWords,
        updateLearningWords: (updated) => setState(() => _learningWords
          ..clear()
          ..addAll(updated)),
        loadWordStats: _loadWordStats,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.onSurfaceVariant.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Word
            Expanded(
              child: Text(
                word,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Circular Progress Indicator
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 3,
                    backgroundColor: colorScheme.onSurfaceVariant.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onSurfaceVariant.withOpacity(0.1),
                    ),
                  ),
                  // Progress circle
                  CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                  // Center icon or percentage
                  Text(
                    isMastered ? '100%' : '${(progressValue * 100).round()}%',
                    style: TextStyle(
                      fontSize: isMastered ? 8 : 9,
                      fontWeight: isMastered ? FontWeight.w700 : FontWeight.w600,
                      color: progressColor,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernWordCard(String word, String nativeWord) {
    final colorScheme = Theme.of(context).colorScheme;
    final matching = _learningWords.firstWhere(
      (element) => element['word'] == word.toLowerCase(),
      orElse: () => {},
    );

    final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
    final reps = matching.isEmpty ? 0 : (matching['reps'] ?? 0);

    final isMastered = scheduledDays >= 100 || scheduledDays == -1;
    final isLearned = scheduledDays >= 80 && scheduledDays != -1;
    final isLearning = !isMastered && !isLearned && reps > 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (isMastered) {
      statusColor = Colors.green;
      statusText = 'Mastered';
      statusIcon = Icons.star_rounded;
    } else if (isLearned) {
      statusColor = Colors.blue;
      statusText = 'Learned';
      statusIcon = Icons.check_circle_rounded;
    } else if (isLearning) {
      statusColor = Colors.orange;
      statusText = 'Learning';
      statusIcon = Icons.school_rounded;
    } else {
      statusColor = colorScheme.onSurfaceVariant;
      statusText = 'New';
      statusIcon = Icons.circle_outlined;
    }

    return InkWell(
      onTap: () => showCenteredToast(context, nativeWord),
      onLongPress: () => showMarkAsMasteredModal(
        context: context,
        word: word,
        categoryName: widget.category['name'],
        targetLanguage: widget.targetLanguage,
        learningWords: _learningWords,
        updateLearningWords: (updated) => setState(() => _learningWords
          ..clear()
          ..addAll(updated)),
        loadWordStats: _loadWordStats,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: statusColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Word and Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  statusIcon,
                  size: 16,
                  color: statusColor,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Status and Progress
            Row(
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                if (!isMastered)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: scheduledDays / 100,
                        minHeight: 4,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSortedWords(List allWords) {
    return allWords.map((word) {
      final matching = _learningWords.firstWhere(
        (element) => element['word'] == word.toString().toLowerCase(),
        orElse: () => {},
      );
      final scheduledDays = matching.isEmpty ? 0.0 : (matching['scheduledDays'] is int ? (matching['scheduledDays'] as int).toDouble() : (matching['scheduledDays'] as double));
      final reps = matching.isEmpty ? 0 : (matching['reps'] ?? 0);

      final isMastered = scheduledDays >= 100 || scheduledDays == -1;
      final isLearned = scheduledDays >= 80 && scheduledDays != -1;
      final isLearning = !isMastered && !isLearned && reps > 0;

      int priority;
      if (isLearning) {
        priority = 0; // Show learning words first
      } else if (!isMastered && !isLearned) {
        priority = 1; // Then new words
      } else if (isLearned) {
        priority = 2; // Then learned words
      } else {
        priority = 3; // Mastered words last
      }

      return {
        'word': word.toString(),
        'priority': priority,
        'score': scheduledDays,
        'index': allWords.indexOf(word),
      };
    }).toList()
      ..sort((a, b) {
        final cmp = (a['priority'] as int).compareTo(b['priority'] as int);
        if (cmp != 0) return cmp;
        return (b['score'] as double).compareTo(a['score'] as double);
      });
  }

  void _showTranslationSheet(BuildContext context, String word, String nativeWord) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(height: 20),

                // Target language word
                Text(
                  word,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _getCategoryColor(widget.category['name']),
                  ),
                ),

                const SizedBox(height: 8),

                // Arrow or divider
                Icon(
                  Icons.arrow_downward_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),

                const SizedBox(height: 8),

                // Native language translation
                Text(
                  nativeWord,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getCategoryColor(widget.category['name']),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Got it',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
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
  }

  void _showAllLessonsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
              child: Column(
                children: [
                  // Modal header
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: _getCategoryColor(widget.category['name']),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.category['name']} Lessons',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Lessons List
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      itemCount: _categoryLessons.length,
                      itemBuilder: (context, index) {
                        return LessonCard(
                          audioFile: _categoryLessons[index],
                          onReload: _loadCategoryLessons,
                          isSmallScreen: MediaQuery.of(context).size.height < 700,
                          showCategoryBadge: false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // Helper method to generate colors based on category name
  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'at the coffee shop':
        return const Color(0xFF5D4037);
      case 'weather talk':
        return const Color(0xFF303F9F);
      case 'in the supermarket':
        return const Color(0xFF388E3C);
      case 'asking for directions':
        return const Color(0xFF1976D2);
      case 'making small talk':
        return const Color(0xFF00695C);
      case 'at the airport':
        return const Color(0xFF455A64);
      case 'at the restaurant':
        return const Color(0xFFD84315);
      case 'at the hotel':
        return const Color(0xFF4E342E);
      case 'at the doctor\'s office':
        return const Color(0xFFC62828);
      case 'public transportation':
        return const Color(0xFF7B1FA2);
      case 'shopping for clothes':
        return const Color(0xFFC2185B);
      case 'at the gym':
        return const Color(0xFFEF6C00);
      case 'at the bank':
        return const Color(0xFF512DA8);
      case 'at the post office':
        return const Color(0xFF00838F);
      case 'at the pharmacy':
        return const Color(0xFF0097A7);
      case 'at the park':
        return const Color(0xFF689F38);
      case 'at the beach':
        return const Color(0xFF0288D1);
      case 'at the library':
        return const Color(0xFF3949AB);
      case 'at the cinema':
        return const Color(0xFF5E35B1);
      case 'at the hair salon':
        return const Color(0xFFAD1457);
      case 'custom lesson':
        return const Color(0xFF546E7A);
      default:
        final int hashCode = categoryName.toLowerCase().hashCode;
        return Color((hashCode & 0xFFFFFF) | 0xFF000000).withOpacity(0.6);
    }
  }
}

void showCenteredToast(BuildContext context, String message) {
  final colorScheme = Theme.of(context).colorScheme;
  final overlay = Overlay.of(context);

  // Dismiss any existing toast first
  if (_activeToastEntry != null) {
    _activeToastEntry!.remove();
    _activeToastEntry = null;
  }

  final overlayEntry = OverlayEntry(
    builder: (context) => Center(
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    ),
  );

  // Save reference to current toast
  _activeToastEntry = overlayEntry;
  overlay.insert(overlayEntry);

  Future.delayed(const Duration(seconds: 2), () {
    // Only remove if this is still the active toast
    if (_activeToastEntry == overlayEntry) {
      overlayEntry.remove();
      _activeToastEntry = null;
    }
  });
}
