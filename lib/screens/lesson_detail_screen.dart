import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/main.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/services/lesson_detail_service.dart';
import 'package:parakeet/widgets/lesson_detail_screen/lesson_detail_content.dart';
import 'package:parakeet/services/lesson_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final String category;
  final List<String> allWords;
  final String title;
  final String topic;
  final List<dynamic> wordsToLearn;
  final String languageLevel;
  final String length;
  final String nativeLanguage;
  final String targetLanguage;

  // Static tracking of active instances to help with cleanup
  static final Set<String> _activeScreenIds = {};

  // Method to clear any static or shared resources when navigating to a new screen
  static void resetStaticState() {
    _activeScreenIds.clear();
  }

  const LessonDetailScreen({
    Key? key,
    required this.category,
    required this.allWords,
    required this.title,
    required this.topic,
    required this.wordsToLearn,
    required this.languageLevel,
    required this.length,
    required this.nativeLanguage,
    required this.targetLanguage,
  }) : super(key: key);

  @override
  _LessonDetailScreenState createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  bool _isGeneratingLesson = false;
  late TTSProvider ttsProvider;

  // State variables for regeneration
  late String _title;
  late String _topic;
  late List<dynamic> _wordsToLearn;

  // Maximum number of words that can be selected
  final int _maxWordsAllowed = 5;

  void _handleBack(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(context, '/create_lesson', (route) => false);
  }

  // Function to handle lesson regeneration
  Future<void> _regenerateLesson() async {
    // Show regeneration confirmation dialog
    final bool? shouldRegenerate = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Lesson?'),
          content: const Text('This will create a lesson in same category with different title and topic. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Regenerate'),
            ),
          ],
        );
      },
    );

    if (shouldRegenerate != true) return;

    setState(() {
      _isGeneratingLesson = true;
    });

    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );
      }

      // Call the service to regenerate the lesson
      final result = await LessonDetailService.regenerateLesson(
        context: context,
        category: widget.category,
        allWords: widget.allWords,
        targetLanguage: widget.targetLanguage,
        nativeLanguage: widget.nativeLanguage,
      );
      List<dynamic> wordsToLearn = await LessonService.selectWordsFromCategory(widget.category, widget.allWords, widget.targetLanguage);

      if (result != null && mounted) {
        Navigator.pop(context); // Close loading dialog

        // Update the current screen state instead of navigating to a new one
        setState(() {
          // Update the state with new values from the API response
          _title = result['title'] as String;
          _topic = result['topic'] as String;
          _wordsToLearn = wordsToLearn;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New lesson generated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Scroll to top of the screen for better UX
        await Future.delayed(const Duration(milliseconds: 300));
      }
    } finally {
      // Reset generation state
      if (mounted) {
        setState(() {
          _isGeneratingLesson = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final textScaleFactor = isSmallScreen ? 0.95 : 1.05;

    return ResponsiveScreenWrapper(
      child: PopScope(
        canPop: false,
        onPopInvoked: (bool didPop) async {
          if (didPop) return;
          _handleBack(context);
        },
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(isSmallScreen || kIsWeb ? 48.0 : 56.0),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(
                'Lesson Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: (isSmallScreen || kIsWeb ? 19 : 21) * textScaleFactor,
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBack(context),
              ),
              actions: [
                // Regenerate button in app bar
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Regenerate Lesson',
                  onPressed: _isGeneratingLesson ? null : _regenerateLesson,
                ),
              ],
            ),
          ),
          body: LessonDetailContent(
            category: widget.category,
            title: _title,
            topic: _topic,
            wordsToLearn: _wordsToLearn,
            allWords: widget.allWords,
            nativeLanguage: widget.nativeLanguage,
            targetLanguage: widget.targetLanguage,
            languageLevel: widget.languageLevel,
            length: widget.length,
            isGeneratingLesson: _isGeneratingLesson,
            maxWordsAllowed: _maxWordsAllowed,
            onWordsChanged: (words) {
              setState(() {
                _wordsToLearn = words;
              });
            },
            setIsGeneratingLesson: (value) {
              setState(() {
                _isGeneratingLesson = value;
              });
            },
          ),
          bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Generate a unique ID for this instance
    final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add this instance to active screens
    LessonDetailScreen._activeScreenIds.add(instanceId);

    // Initialize fields
    ttsProvider = widget.targetLanguage == 'Azerbaijani' ? TTSProvider.openAI : TTSProvider.googleTTS;
    _isGeneratingLesson = false;

    // Initialize state variables with widget values
    _title = widget.title;
    _topic = widget.topic;
    // Convert all words to lowercase
    _wordsToLearn = List<String>.from(widget.wordsToLearn.map((word) => word.toLowerCase()));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when this screen becomes active again
    setState(() {
      _isGeneratingLesson = false;
    });
  }

  @override
  void dispose() {
    // Make sure to clear any state or resources when disposed
    _isGeneratingLesson = false;

    // Clear static resources for this widget
    if (LessonDetailScreen._activeScreenIds.length > 1) {
      print("Warning: LessonDetailScreen - Multiple instances detected during disposal");
    }

    super.dispose();
  }
}
