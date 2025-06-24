import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/main.dart';
import 'package:parakeet/services/category_level_service.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/widgets/home_screen/lesson_card.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:parakeet/utils/constants.dart';

class LevelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  final Map<String, dynamic> nativeCategory;
  final String nativeLanguage;
  final String targetLanguage;
  final String languageLevel;
  final int levelNumber;

  const LevelDetailScreen({
    Key? key,
    required this.category,
    required this.nativeCategory,
    required this.nativeLanguage,
    required this.targetLanguage,
    required this.languageLevel,
    required this.levelNumber,
  }) : super(key: key);

  @override
  State<LevelDetailScreen> createState() => _LevelDetailScreenState();
}

class _LevelDetailScreenState extends State<LevelDetailScreen> {
  final List<DocumentSnapshot> _levelLessons = [];
  final Map<String, bool> _lessonCompletionStatus = {};
  bool _isLoadingLessons = true;
  bool _isGeneratingLesson = false;
  int _generationsRemaining = 0;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadLevelLessons();
    _loadGenerationsRemaining();
  }

  Future<void> _loadLevelLessons() async {
    setState(() => _isLoadingLessons = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

      final allCategoryLessons = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        String lessonCategory;
        if (data?.containsKey('category') == true && doc.get('category') != null && doc.get('category').toString().trim().isNotEmpty) {
          lessonCategory = doc.get('category');
        } else {
          lessonCategory = 'Custom Lesson';
        }
        return lessonCategory == widget.category['name'];
      }).toList();

      // Filter by level asynchronously
      final categoryLessons = <DocumentSnapshot>[];
      for (final doc in allCategoryLessons) {
        final parentDocId = doc.reference.parent.parent!.id;
        final lessonLevel = await _getLessonLevel(parentDocId);
        if (lessonLevel == widget.levelNumber) {
          categoryLessons.add(doc);
        }
      }

      // Sort by timestamp (newest first)
      categoryLessons.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

      // Load completion status for each lesson
      _lessonCompletionStatus.clear();
      final completionFutures = categoryLessons.map((lesson) async {
        final parentDocId = lesson.reference.parent.parent!.id;
        try {
          final doc = await FirebaseFirestore.instance.collection('chatGPT_responses').doc(parentDocId).get();
          final isCompleted = doc.exists && doc.data()?['completed'] == true;
          _lessonCompletionStatus[parentDocId] = isCompleted;
        } catch (e) {
          print('Error checking completion status for lesson $parentDocId: $e');
          _lessonCompletionStatus[parentDocId] = false;
        }
      });

      await Future.wait(completionFutures);

      if (mounted) {
        setState(() {
          _levelLessons.clear();
          _levelLessons.addAll(categoryLessons);
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      print('Error loading level lessons: $e');
      setState(() => _isLoadingLessons = false);
    }
  }

  Future<int> _getLessonLevel(String documentId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['categoryLevel'] ?? 1; // Default to level 1 if no level specified
      }
    } catch (e) {
      print('Error getting lesson level for $documentId: $e');
    }
    return 1; // Default to level 1
  }

  Future<void> _loadGenerationsRemaining() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final isPremium = userDoc.data()?['premium'] ?? false;
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

  int _getCompletedLessonsCount() {
    int completedCount = 0;
    for (final lesson in _levelLessons) {
      final parentDocId = lesson.reference.parent.parent!.id;
      if (_lessonCompletionStatus[parentDocId] == true) {
        completedCount++;
      }
    }
    return completedCount;
  }

  bool _isLevelCompleted() {
    final requiredLessons = CategoryLevelService.levelRequirements[widget.levelNumber] ?? 3;
    return _getCompletedLessonsCount() >= requiredLessons;
  }

  bool _hasEnoughGeneratedLessons() {
    final requiredLessons = CategoryLevelService.levelRequirements[widget.levelNumber] ?? 3;
    return _levelLessons.length >= requiredLessons;
  }

  Future<void> _handleCreateNewLesson() async {
    // Check if no generations remaining - show upgrade modal
    if (_generationsRemaining <= 0) {
      final canProceed = await LessonService.checkPremiumAndAPILimits(context);
      return; // Don't proceed with lesson generation
    }

    setState(() => _isGeneratingLesson = true);

    final canProceed = await LessonService.checkPremiumAndAPILimits(context);
    if (!canProceed) {
      setState(() => _isGeneratingLesson = false);
      return;
    }

    try {
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
          "level_number": widget.levelNumber,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to generate lesson topic');
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final String title = result['title'] as String;
      final String topic = result['topic'] as String;

      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
      final String documentId = docRef.id;
      final String userId = FirebaseAuth.instance.currentUser!.uid.toString();
      final TTSProvider ttsProvider = widget.targetLanguage == 'Azerbaijani' ? TTSProvider.openAI : TTSProvider.googleTTS;

      DocumentReference scriptDocRef = firestore.collection('chatGPT_responses').doc(documentId).collection('script-$userId').doc();

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
          "tts_provider": ttsProvider.value.toString()
        }),
      );

      await FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentId).set({
        'categoryLevel': widget.levelNumber,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final navigationResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(
            category: widget.category['name'],
            dialogue: const [],
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

      if (navigationResult == 'reload') {
        _loadLevelLessons();
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
      setState(() => _isGeneratingLesson = false);
      _loadGenerationsRemaining();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final levelColor = CategoryLevelService.getLevelColor(widget.levelNumber);
    final levelName = widget.levelNumber == 1
        ? 'Beginner'
        : widget.levelNumber == 2
            ? 'Intermediate'
            : 'Advanced';
    final requiredLessons = CategoryLevelService.levelRequirements[widget.levelNumber] ?? 3;

    return ResponsiveScreenWrapper(
      child: AbsorbPointer(
        absorbing: _isGeneratingLesson,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Column(
              children: [
                Text(
                  widget.category['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Level ${widget.levelNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Level Progress Section
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            levelColor.withOpacity(0.1),
                            levelColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: levelColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: levelColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  CategoryLevelService.getLevelIcon(widget.levelNumber),
                                  color: levelColor,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Level ${widget.levelNumber}: $levelName',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_getCompletedLessonsCount()}/$requiredLessons lessons completed',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Progress',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (_isLevelCompleted())
                                        const Text(
                                          '🎉 ',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      Text(
                                        '${(((_getCompletedLessonsCount() / requiredLessons) * 100).clamp(0, 100)).round()}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: levelColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: (_getCompletedLessonsCount() / requiredLessons).clamp(0.0, 1.0),
                                  minHeight: 12,
                                  backgroundColor: levelColor.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                                ),
                              ),
                              // Status message below progress bar
                              if (!_isLoadingLessons && (_hasEnoughGeneratedLessons() || _isLevelCompleted()))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isLevelCompleted() ? Icons.check_circle_rounded : Icons.play_circle_rounded,
                                        color: _isLevelCompleted() ? Colors.green : Colors.orange,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _isLevelCompleted()
                                              ? (widget.levelNumber < 3 ? 'Move to Level ${widget.levelNumber + 1} to continue your journey.' : 'You\'ve mastered all levels in this category!')
                                              : 'Complete ${(CategoryLevelService.levelRequirements[widget.levelNumber] ?? 3) - _getCompletedLessonsCount()} more lessons${widget.levelNumber < 3 ? ' to unlock Level ${widget.levelNumber + 1}' : ' to master this category'}.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _isLevelCompleted() ? Colors.green : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Lessons Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: levelColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: levelColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isLoadingLessons ? 'Loading Lessons...' : 'Generated Lessons',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (!_isLoadingLessons)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: levelColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_levelLessons.length}/${CategoryLevelService.levelRequirements[widget.levelNumber] ?? 3}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: levelColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isLoadingLessons)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: CircularProgressIndicator(color: levelColor),
                              ),
                            )
                          else if (_levelLessons.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 48,
                                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No lessons yet',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Generate your first Level ${widget.levelNumber} lesson to get started!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          else
                            ...(_levelLessons.map((lesson) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: LessonCard(
                                    audioFile: lesson,
                                    onReload: _loadLevelLessons,
                                    isSmallScreen: isSmallScreen,
                                    showCategoryBadge: false,
                                  ),
                                ))),
                        ],
                      ),
                    ),

                    const SizedBox(height: 120),
                  ],
                ),
              ),
              if (_isGeneratingLesson) Container(color: Colors.black.withOpacity(0.3)),
            ],
          ),
          floatingActionButton: _hasEnoughGeneratedLessons()
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 20, right: 4),
                  child: FloatingActionButton.extended(
                    onPressed: _isGeneratingLesson ? null : _handleCreateNewLesson,
                    backgroundColor: _generationsRemaining <= 0 ? Colors.grey.shade600 : levelColor,
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
                        : Icon(_generationsRemaining <= 0 ? Icons.lock_rounded : Icons.auto_awesome_rounded, size: 22),
                    label: _isGeneratingLesson
                        ? const Text(
                            'Generating...',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : _generationsRemaining <= 0 && _isPremium
                            ? const Text(
                                'Daily Limit Reached',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _generationsRemaining <= 0 ? 'Upgrade to Generate' : 'Generate Lesson',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _generationsRemaining <= 0 ? 'Daily limit reached' : '$_generationsRemaining credits remaining',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
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
      ),
    );
  }
}
