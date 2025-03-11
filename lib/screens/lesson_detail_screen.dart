import 'package:flutter/material.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/main.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/screens/audio_player_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final String category;
  final List<String> allWords;
  final String title;
  final String topic;
  final List<String> wordsToLearn;
  final String languageLevel;
  final String length;
  final String nativeLanguage;
  final String targetLanguage;

  // Static tracking of active instances to help with cleanup
  static final Set<String> _activeScreenIds = {};

  // Method to clear any static or shared resources when navigating to a new screen
  static void resetStaticState() {
    print("LessonDetailScreen - resetStaticState called");
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
  late Map<String, dynamic> firstDialogue;
  late TTSProvider ttsProvider;

  // State variables for regeneration
  late String _title;
  late String _topic;
  late List<String> _wordsToLearn;

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
          content: const Text('This will create a lesson in same category with different title, topic, and words to learn. Continue?'),
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

      // Make the API call to generate a new lesson topic
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8080'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "category": widget.category,
          "allWords": widget.allWords,
          "target_language": widget.targetLanguage,
          "native_language": widget.nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;

        if (mounted) Navigator.pop(context); // Close loading dialog

        // Update the current screen state instead of navigating to a new one
        if (mounted) {
          setState(() {
            // Update the state with new values from the API response
            _title = result['title'] as String;
            _topic = result['topic'] as String;
            _wordsToLearn = (result['words_to_learn'] as List).cast<String>();
            firstDialogue = <String, dynamic>{}; // Reset dialogue for next generation
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
      } else {
        throw Exception('Failed to generate new lesson topic');
      }
    } catch (e) {
      print(e);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
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

  // Function to show word selection dialog
  Future<void> _showWordSelectionDialog() async {
    // Create a temporary list to track selected words
    List<String> tempSelectedWords = List<String>.from(_wordsToLearn);

    // Get screen size for responsive dialog
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 600 ? 500.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.6;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: (screenSize.width - dialogWidth) / 2,
              vertical: 24,
            ),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(maxHeight: dialogHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Select Words to Learn (${tempSelectedWords.length}/$_maxWordsAllowed)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (tempSelectedWords.length >= _maxWordsAllowed)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Maximum $_maxWordsAllowed words allowed. Unselect a word to select another.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: widget.allWords.length,
                      itemBuilder: (context, index) {
                        final word = widget.allWords[index].toLowerCase();
                        final isSelected = tempSelectedWords.map((w) => w.toLowerCase()).contains(word);

                        return CheckboxListTile(
                          title: Text(
                            word,
                            style: const TextStyle(fontSize: 18),
                          ),
                          value: isSelected,
                          onChanged: (tempSelectedWords.length >= _maxWordsAllowed && !isSelected)
                              ? null // Disable checkbox if max words reached and this word is not selected
                              : (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      tempSelectedWords.add(word);
                                    } else {
                                      tempSelectedWords.removeWhere((w) => w.toLowerCase() == word.toLowerCase());
                                    }
                                  });
                                },
                          activeColor: Theme.of(context).colorScheme.primary,
                          dense: true,
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: tempSelectedWords.isEmpty
                              ? null // Disable save button if no words selected
                              : () {
                                  setState(() {
                                    // Ensure all words are lowercase when saving
                                    _wordsToLearn = tempSelectedWords.map((w) => w.toLowerCase()).toList();
                                  });
                                  Navigator.of(context).pop();
                                },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isSmallScreen ? 8 : 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with Category and Regenerate button
              Row(
                children: [
                  // Category Container
                  Expanded(
                    flex: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Category',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13 * textScaleFactor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.category,
                            style: TextStyle(
                              fontSize: 17 * textScaleFactor,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title Section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        fontSize: 19 * textScaleFactor,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Topic Section
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                height: isSmallScreen ? 100 : 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _topic,
                          style: TextStyle(
                            fontSize: 15 * textScaleFactor,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Words to Repeat Section with Edit button
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Words to learn (${_wordsToLearn.length}/$_maxWordsAllowed)',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13 * textScaleFactor,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 18 * textScaleFactor,
                            color: colorScheme.primary,
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Edit words',
                          onPressed: _isGeneratingLesson ? null : _showWordSelectionDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _wordsToLearn
                          .map((word) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.primary.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  word.toLowerCase(),
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 14 * textScaleFactor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Start Lesson Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isGeneratingLesson || _wordsToLearn.isEmpty
                        ? null // Disable button while generating or if no words selected
                        : () async {
                            // Prevent multiple generations
                            if (_isGeneratingLesson) return;

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

                              final FirebaseFirestore firestore = FirebaseFirestore.instance;
                              final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
                              final String documentId = docRef.id;
                              final String userId = FirebaseAuth.instance.currentUser!.uid.toString();

                              // Make the first API call
                              http.post(
                                Uri.parse('http://192.168.2.105:8081'),
                                headers: <String, String>{
                                  'Content-Type': 'application/json; charset=UTF-8',
                                  "Access-Control-Allow-Origin": "*",
                                },
                                body: jsonEncode(<String, dynamic>{
                                  "requested_scenario": _topic,
                                  "keywords": _wordsToLearn,
                                  "native_language": widget.nativeLanguage,
                                  "target_language": widget.targetLanguage,
                                  "length": widget.length,
                                  "user_ID": userId,
                                  "language_level": widget.languageLevel,
                                  "document_id": documentId,
                                  "tts_provider": ttsProvider.value.toString(),
                                }),
                              );

                              int counter = 0;
                              bool docExists = false;
                              while (!docExists && counter < 15 && mounted) {
                                counter++;
                                await Future.delayed(const Duration(seconds: 1));
                                final QuerySnapshot snapshot = await docRef.collection('only_target_sentences').get();
                                if (snapshot.docs.isNotEmpty) {
                                  docExists = true;
                                  final Map<String, dynamic> data = snapshot.docs.first.data() as Map<String, dynamic>;
                                  firstDialogue = data;

                                  if (firstDialogue.isNotEmpty && mounted) {
                                    // Create an empty script document ID
                                    DocumentReference scriptDocRef = firestore.collection('chatGPT_responses').doc(documentId).collection('script-$userId').doc();

                                    // Navigate directly to AudioPlayerScreen
                                    if (mounted) Navigator.pop(context); // Close loading dialog
                                    if (mounted) {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AudioPlayerScreen(
                                            dialogue: firstDialogue["dialogue"] ?? [],
                                            title: firstDialogue["title"] ?? _title,
                                            documentID: documentId,
                                            userID: userId,
                                            scriptDocumentId: scriptDocRef.id,
                                            generating: true,
                                            targetLanguage: widget.targetLanguage,
                                            nativeLanguage: widget.nativeLanguage,
                                            languageLevel: widget.languageLevel,
                                            wordsToRepeat: _wordsToLearn,
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    throw Exception('Proper data not received from API');
                                  }
                                }
                              }
                              if (!docExists && mounted) {
                                throw Exception('Failed to find the response in firestore within 15 seconds');
                              }
                            } on Exception catch (e) {
                              print(e);
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Oops, this is embarrassing 😅 Something went wrong! Please try again.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } finally {
                              // Reset generation state
                              if (mounted) {
                                setState(() {
                                  _isGeneratingLesson = false;
                                });
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Start Lesson',
                      style: TextStyle(
                        fontSize: 17 * textScaleFactor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
      ),
    ));
  }

  @override
  void initState() {
    super.initState();
    print("LessonDetailScreen - initState() called");

    // Generate a unique ID for this instance
    final String instanceId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add this instance to active screens
    LessonDetailScreen._activeScreenIds.add(instanceId);
    print("LessonDetailScreen - Active screens: ${LessonDetailScreen._activeScreenIds.length}");

    // Initialize fields
    firstDialogue = <String, dynamic>{};
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
    print("LessonDetailScreen - didChangeDependencies() called");
    // Reset state when this screen becomes active again
    setState(() {
      _isGeneratingLesson = false;
    });
  }

  @override
  void dispose() {
    print("LessonDetailScreen - dispose() called");
    // Make sure to clear any state or resources when disposed
    firstDialogue.clear();
    _isGeneratingLesson = false;

    // Clear static resources for this widget
    if (LessonDetailScreen._activeScreenIds.length > 1) {
      print("LessonDetailScreen - Warning: Multiple instances detected during disposal");
    }

    super.dispose();
  }
}
