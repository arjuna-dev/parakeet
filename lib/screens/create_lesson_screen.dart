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
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/utils/constants.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> with SingleTickerProviderStateMixin {
  final activeCreationAllowed = 20;
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';
  late TabController _tabController;

  // Custom lesson form controllers
  final TextEditingController _topicController = TextEditingController();
  final List<String> _selectedWords = [];
  final int _maxWordsAllowed = 5;
  bool _isCreatingCustomLesson = false;
  bool _isSuggestingRandom = false;

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
    _topicController.dispose();
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

  Future<bool> _checkPremiumAndAPILimits() async {
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
          return false;
        }
      }
    }

    var usersInActiveCreation = await countUsersInActiveCreation();
    if (usersInActiveCreation != -1 && usersInActiveCreation > activeCreationAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oops, this is embarrassing 😅 Too many users are creating lessons right now. Please try again in a moment.'),
          duration: Duration(seconds: 5),
        ),
      );
      return false;
    }

    var apiCallsByUser = await countAPIcallsByUser();
    if (apiCallsByUser != -1 && apiCallsByUser >= getAPICallLimit(isPremium)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPremium ? 'Unfortunately, you have reached the maximum number of creation for today 🙃. Please try again tomorrow.' : 'You\'ve reached the free limit. Upgrade to premium for more lessons!'),
          duration: const Duration(seconds: 5),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _handleCategorySelection(Map<String, dynamic> category) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final canProceed = await _checkPremiumAndAPILimits();
    if (!canProceed) {
      Navigator.pop(context); // Close loading dialog
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
              category: category['name'] as String,
              allWords: category['words'] as List<String>,
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

  void _addWord(String word) {
    if (word.isEmpty) return;

    setState(() {
      if (_selectedWords.length < _maxWordsAllowed) {
        final normalizedWord = word.trim().toLowerCase();
        if (!_selectedWords.contains(normalizedWord)) {
          _selectedWords.add(normalizedWord);
        }
      }
    });
  }

  void _removeWord(String word) {
    setState(() {
      _selectedWords.remove(word);
    });
  }

  Future<void> _showAddWordDialog() async {
    final TextEditingController wordController = TextEditingController();
    String? wordValue;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add Word (${_selectedWords.length}/$_maxWordsAllowed)',
            style: const TextStyle(fontSize: 18),
          ),
          content: TextField(
            controller: wordController,
            decoration: const InputDecoration(
              hintText: 'Enter a word',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                wordValue = value;
                Navigator.pop(dialogContext);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (wordController.text.isNotEmpty) {
                  wordValue = wordController.text;
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    // Add the word after the dialog is closed and controller is disposed
    if (wordValue != null && wordValue!.isNotEmpty) {
      _addWord(wordValue!);
      print(_selectedWords);
    }

    wordController.dispose();
  }

  Future<void> _createCustomLesson() async {
    // Validate inputs
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a topic for your lesson'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one word to learn'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingCustomLesson = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    final canProceed = await _checkPremiumAndAPILimits();
    if (!canProceed) {
      Navigator.pop(context); // Close loading dialog
      setState(() {
        _isCreatingCustomLesson = false;
      });
      return;
    }

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
      final String documentId = docRef.id;
      final String userId = FirebaseAuth.instance.currentUser!.uid.toString();
      final String topic = _topicController.text.trim();

      // Make the API call
      http.post(
        Uri.parse('http://192.168.2.105:8081'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "requested_scenario": topic,
          "keywords": _selectedWords,
          "native_language": nativeLanguage,
          "target_language": targetLanguage,
          "length": '4',
          "user_ID": userId,
          "language_level": languageLevel,
          "document_id": documentId,
          "tts_provider": targetLanguage == 'Azerbaijani' ? TTSProvider.openAI.value.toString() : TTSProvider.googleTTS.value.toString(),
        }),
      );

      int counter = 0;
      bool docExists = false;
      Map<String, dynamic> firstDialogue = {};

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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AudioPlayerScreen(
                    dialogue: firstDialogue["dialogue"] ?? [],
                    title: firstDialogue["title"] ?? topic,
                    documentID: documentId,
                    userID: userId,
                    scriptDocumentId: scriptDocRef.id,
                    generating: true,
                    targetLanguage: targetLanguage,
                    nativeLanguage: nativeLanguage,
                    languageLevel: languageLevel,
                    wordsToRepeat: List<dynamic>.from(_selectedWords),
                  ),
                ),
              );

              // Reset form
              _topicController.clear();
            }
          } else {
            throw Exception('Proper data not received from API');
          }
        }
      }

      if (!docExists && mounted) {
        throw Exception('Failed to find the response in firestore within 15 seconds');
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
      if (mounted) {
        setState(() {
          _isCreatingCustomLesson = false;
        });
      }
    }
  }

  Future<void> _suggestRandomLesson() async {
    setState(() {
      _isSuggestingRandom = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8082'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(<String, dynamic>{
          "target_language": targetLanguage,
          "native_language": nativeLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;

        setState(() {
          // Clear existing data
          _topicController.text = result['topic'] as String;
          _selectedWords.clear();

          // Add new words
          final wordsToLearn = (result['words_to_learn'] as List).cast<String>();
          for (var word in wordsToLearn) {
            if (_selectedWords.length < _maxWordsAllowed) {
              _selectedWords.add(word);
            }
          }
        });
      } else {
        throw Exception('Failed to get random lesson suggestion');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to get random suggestion: ${e.toString()}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSuggestingRandom = false;
      });
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
                ListView.builder(
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

                // Custom Lesson Tab
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isSmallScreen ? 8 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topic Input
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Topic',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isSuggestingRandom ? null : _suggestRandomLesson,
                                  icon: _isSuggestingRandom
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                          ),
                                        )
                                      : const Icon(Icons.auto_awesome, size: 16),
                                  label: const Text('Suggest Random'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    visualDensity: VisualDensity.compact,
                                    textStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _topicController,
                              decoration: InputDecoration(
                                hintText: 'Enter a topic for your lesson',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface,
                              ),
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Example: "Ordering food at a restaurant" or "Asking for directions"',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Words to Learn
                      Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Words to Learn (${_selectedWords.length}/$_maxWordsAllowed)',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.add_circle,
                                    color: _selectedWords.length >= _maxWordsAllowed ? colorScheme.onSurfaceVariant.withOpacity(0.5) : colorScheme.primary,
                                    size: 24,
                                  ),
                                  onPressed: _selectedWords.length >= _maxWordsAllowed ? null : _showAddWordDialog,
                                  tooltip: 'Add word',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedWords.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    'Add up to 5 words you want to learn',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedWords.map((word) {
                                  return Chip(
                                    label: Text(word),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () => _removeWord(word),
                                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                                    side: BorderSide(
                                      color: colorScheme.primary.withOpacity(0.2),
                                    ),
                                    labelStyle: TextStyle(
                                      color: colorScheme.primary,
                                    ),
                                    deleteIconColor: colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Create Lesson Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isCreatingCustomLesson || _selectedWords.isEmpty || _topicController.text.trim().isEmpty ? null : _createCustomLesson,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isCreatingCustomLesson
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  'Create Custom Lesson',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 16 : 18,
                                    fontWeight: FontWeight.bold,
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
        ],
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
