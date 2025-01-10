import 'dart:math';
import 'package:parakeet/screens/confirm_dialogue_screen.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/utils/activate_free_trial.dart';
import 'dart:convert';
import 'package:parakeet/utils/supported_language_codes.dart';
import 'package:parakeet/utils/native_language_list.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/utils/example_scenarios.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:parakeet/utils/nickname_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateLesson extends StatefulWidget {
  const CreateLesson({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  State<CreateLesson> createState() => _CreateLessonState();
}

class _CreateLessonState extends State<CreateLesson> {
  var topic = '';
  var keywords = '';
  var ttsProvider = TTSProvider.googleTTS;
  var nativeLanguage = 'English (US)';
  var targetLanguage = 'German';
  var length = '4';
  var languageLevel = 'Absolute beginner (A1)';
  final TextEditingController _controller = TextEditingController();
  final activeCreationAllowed = 20; // change this to allow more users
  bool isGeneratingNickname = false;

  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> firstDialogue = {};

  @override
  void initState() {
    super.initState();
    _controller.text = example_scenarios[Random().nextInt(example_scenarios.length)]; // Set initial random topic
    topic = _controller.text;
    _loadUserPreferences();
  }

  void _loadUserPreferences() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentReference docRef = firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('native_language')) {
          setState(() {
            nativeLanguage = data['native_language'];
          });
        }
        if (data.containsKey('target_language')) {
          setState(() {
            targetLanguage = data['target_language'];
          });
        }
        if (data.containsKey('language_level')) {
          setState(() {
            languageLevel = data['language_level'];
          });
        }
      }
    } catch (e) {
      print('Error fetching user preferences: $e');
    }
  }

  Future<void> _saveUserPreferences(String key, String value) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).set({key: value}, SetOptions(merge: true));
  }

  void _reloadPage() {
    regenerateTopic();
  }

  void regenerateTopic() {
    setState(() {
      _controller.text = example_scenarios[Random().nextInt(example_scenarios.length)]; // Update with new random topic
      topic = _controller.text;
    });
  }

  Future<int> countUsersInActiveCreation() async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    // Assuming there's a specific document ID you're interested in, replace 'your_document_id' with it
    final DocumentReference docRef = firestore.collection('active_creation').doc('active_creation');

    try {
      final DocumentSnapshot doc = await docRef.get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('users')) {
          final users = data['users'] as List;
          return users.length; // Number of users in the 'users' key
        }
      }
      return 0; // Return 0 if the document doesn't exist or doesn't contain a 'users' key
    } catch (e) {
      print('Error fetching users from active_creation: $e');
      return -1; // Return -1 or handle the error as appropriate
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
          return data['call_count']; // Number of api calls made by the user in that day
        }
      }
      return 0; // Return 0 if the document doesn't exist or doesn't contain a 'users' key
    } catch (e) {
      print('Error fetching api_call counts from user collection: $e');
      return -1; // Return -1 or handle the error as appropriate
    }
  }

  int getAPICallLimit(bool isPremium) {
    return isPremium ? 15 : 5;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final padding = isSmallScreen ? 6.0 : 16.0;

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
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ScrollConfiguration(
              behavior: kIsWeb ? const ScrollBehavior().copyWith(overscroll: false) : const ScrollBehavior(),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppConstants.horizontalPadding.left,
                        vertical: padding,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Topic', Icons.edit_note, isSmallScreen, colorScheme),
                          SizedBox(height: padding / 2),
                          _buildTopicSection(colorScheme, isSmallScreen),
                          SizedBox(height: padding),
                          _buildSectionHeader('Language Settings', Icons.language, isSmallScreen, colorScheme),
                          SizedBox(height: padding / 2),
                          _buildLanguageSection(colorScheme, isSmallScreen),
                          SizedBox(height: padding),
                          _buildCreateButton(colorScheme),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(currentRoute: '/create_lesson'),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isSmallScreen, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 6 : 10,
        horizontal: isSmallScreen ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 18 : 22,
            color: colorScheme.primary,
          ),
          SizedBox(width: isSmallScreen ? 6 : 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSection(ColorScheme colorScheme, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _controller,
                    keyboardType: TextInputType.multiline,
                    maxLines: 2,
                    minLines: 1,
                    maxLength: 400,
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.only(
                        left: 12,
                        right: 60,
                        top: isSmallScreen ? 6 : 12,
                        bottom: isSmallScreen ? 6 : 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      hintText: 'What would you like to learn about?',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      counterText: '', // Hide default counter
                      errorStyle: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: colorScheme.error,
                      ),
                    ),
                    onChanged: (value) => setState(() => topic = value),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a topic';
                      }
                      return null;
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 12, top: isSmallScreen ? 2 : 4),
                    child: Text(
                      '${_controller.text.length}/400',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 4,
                top: 0,
                bottom: 16,
                child: Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 4 : 8,
                        vertical: isSmallScreen ? 2 : 4,
                      ),
                      minimumSize: Size(0, isSmallScreen ? 20 : 24),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: regenerateTopic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: colorScheme.primary,
                          size: isSmallScreen ? 16 : 18,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Suggest',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: isSmallScreen || kIsWeb ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          TextField(
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              labelText: 'Words to include (optional)',
              labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              hintText: 'Enter specific words you want to learn',
              hintStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
              prefixIcon: Icon(Icons.bookmark_border, color: colorScheme.primary, size: isSmallScreen ? 18 : 24),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: isSmallScreen ? 6 : 12,
              ),
            ),
            onChanged: (value) => setState(() => keywords = value),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection(ColorScheme colorScheme, bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: EdgeInsets.all(isSmallScreen || kIsWeb ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdown(
            value: nativeLanguage,
            items: nativeLanguageCodes.keys.toList(),
            label: 'Your Language',
            icon: Icons.person,
            onChanged: (value) async {
              setState(() => nativeLanguage = value.toString());
              await _saveUserPreferences('native_language', value.toString());
              if (value != null) {
                final prefs = await SharedPreferences.getInstance();
                if (prefs.getBool('addressByNickname') ?? false) {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Generating a nice greeting for you... 🚏"),
                      ),
                    );
                    isGeneratingNickname = true;
                    String result = await generateNicknameAudioFiles(
                      language: value.toString(),
                      shouldPlayAudio: true,
                    );
                    if (result == "Daily call limit reached") {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Your name is officially trending! Take a break, you've reached name generation daily limit! 🧘‍♂️"),
                        ),
                      );
                    }
                    isGeneratingNickname = false;
                    print("Nickname audio generated successfully.");
                  } catch (e) {
                    print("Error: $e");
                  }
                }
              }
            },
            isSmallScreen: isSmallScreen,
            colorScheme: colorScheme,
          ),
          SizedBox(height: isSmallScreen || kIsWeb ? 8 : 16),
          _buildDropdown(
            value: targetLanguage,
            items: supportedLanguageCodes.keys.toList(),
            label: 'Learning Language',
            icon: Icons.school,
            onChanged: (value) {
              setState(() {
                targetLanguage = value.toString();
                ttsProvider = value == 'Azerbaijani' ? TTSProvider.openAI : TTSProvider.googleTTS;
              });
            },
            isSmallScreen: isSmallScreen,
            colorScheme: colorScheme,
          ),
          SizedBox(height: isSmallScreen || kIsWeb ? 8 : 16),
          _buildDropdown(
            value: languageLevel,
            items: ['Absolute beginner (A1)', 'Beginner (A2-B1)', 'Intermediate (B2-C1)', 'Advanced (C2)'],
            label: 'Proficiency Level',
            icon: Icons.trending_up,
            onChanged: (value) {
              setState(() => languageLevel = value.toString());
              _saveUserPreferences('language_level', value.toString());
            },
            isSmallScreen: isSmallScreen,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Function(String?) onChanged,
    required bool isSmallScreen,
    required ColorScheme colorScheme,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        labelText: label,
        labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
        prefixIcon: Icon(icon, color: colorScheme.primary, size: isSmallScreen ? 18 : 24),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: isSmallScreen ? 6 : 12,
        ),
      ),
      style: TextStyle(fontSize: isSmallScreen ? 13 : 16, color: Colors.white),
      items: items.map((String item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item == 'Filipino' ? 'Tagalog' : item,
            style: TextStyle(fontSize: isSmallScreen ? 13 : 16, color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCreateButton(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primary,
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        icon: const Icon(Icons.create, size: 20),
        label: const Text(
          'Create Audio Lesson',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          if (isGeneratingNickname) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
            );

            // Wait until isGeneratingNickname becomes false
            await Future.doWhile(() async {
              await Future.delayed(Duration(milliseconds: 100)); // Small delay to prevent CPU hogging
              return isGeneratingNickname;
            });

            // Close the loading dialog
            Navigator.of(context).pop();
          }
          if (_formKey.currentState!.validate()) {
            // Check premium status first
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get();

            final isPremium = userDoc.data()?['premium'] ?? false;
            final hasUsedTrial = userDoc.data()?['hasUsedTrial'] ?? false;

            if (!isPremium) {
              final apiCalls = await countAPIcallsByUser();
              if (apiCalls >= 5) {
                // Activate premium mode prompt
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

            print("pressed");
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
                  content:
                      Text(isPremium ? 'Unfortunately, you have reached the maximum number of creation for today 🙃. Please try again tomorrow.' : 'You\'ve reached the free limit. Upgrade to premium for more lessons!'),
                  duration: const Duration(seconds: 5),
                ),
              );
              return;
            }

            try {
              final FirebaseFirestore firestore = FirebaseFirestore.instance;
              final DocumentReference docRef = firestore.collection('chatGPT_responses').doc();
              print('TTS provider: $ttsProvider');
              http.post(
                Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/first_API_calls'),
                headers: <String, String>{
                  'Content-Type': 'application/json; charset=UTF-8',
                  "Access-Control-Allow-Origin": "*", // Required for CORS support to work
                },
                body: jsonEncode(<String, dynamic>{
                  "requested_scenario": topic,
                  "keywords": keywords,
                  "native_language": nativeLanguage,
                  "target_language": targetLanguage,
                  "length": length,
                  "user_ID": FirebaseAuth.instance.currentUser!.uid.toString(),
                  "language_level": languageLevel,
                  "document_id": docRef.id,
                  "tts_provider": ttsProvider.value.toString(),
                }),
              );
              int counter = 0;
              bool docExists = false;
              while (!docExists && counter < 15) {
                counter++;
                await Future.delayed(const Duration(seconds: 1)); // wait for 1 second
                final QuerySnapshot snapshot = await docRef.collection('only_target_sentences').get();
                if (snapshot.docs.isNotEmpty) {
                  docExists = true;
                  final Map<String, dynamic> data = snapshot.docs.first.data() as Map<String, dynamic>;
                  firstDialogue = data;

                  if (firstDialogue.isNotEmpty) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ConfirmDialogue(firstDialogue: firstDialogue, nativeLanguage: nativeLanguage, targetLanguage: targetLanguage, languageLevel: languageLevel, length: length, documentID: docRef.id),
                      ),
                    ).then((result) {
                      if (result == 'reload') {
                        _reloadPage();
                      }
                    });
                  } else {
                    throw Exception('Proper data not received from API');
                  }
                }
              }
              if (!docExists) {
                throw Exception('Failed to find the response in firestore within 10 second');
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
        },
      ),
    );
  }
}
