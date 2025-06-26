import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/services/user_service.dart';
import 'package:parakeet/widgets/home_screen/custom_lesson_form.dart';
import 'package:parakeet/widgets/home_screen/empty_state_view.dart';
import 'package:parakeet/widgets/home_screen/lesson_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';
import 'package:parakeet/services/lesson_service.dart';
import 'package:parakeet/services/lesson_credit_service.dart';
import 'package:parakeet/services/loading_state_service.dart';

class CustomLessonScreen extends StatefulWidget {
  const CustomLessonScreen({Key? key}) : super(key: key);

  @override
  State<CustomLessonScreen> createState() => _CustomLessonScreenState();
}

class _CustomLessonScreenState extends State<CustomLessonScreen> {
  String nativeLanguage = 'English (US)';
  String targetLanguage = 'German';
  String languageLevel = 'Absolute beginner (A1)';
  bool _isLoading = true;
  bool _isLoadingLessons = true;
  final List<DocumentSnapshot> _customLessons = [];
  int _generationsRemaining = 0;
  bool _isPremium = false;
  bool _showAllLessons = false;
  DateTime? _nextCreditReset;

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadGenerationsRemaining();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset state when navigated back to this screen
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      _loadCustomLessons();
      _loadGenerationsRemaining();
    }
  }

  void _loadUserPreferences() async {
    try {
      final settings = await UserService.getUserLanguageSettings();
      setState(() {
        nativeLanguage = settings['nativeLanguage']!;
        targetLanguage = settings['targetLanguage']!;
        languageLevel = settings['languageLevel']!;
        _isLoading = false;
      });
      // Load custom lessons after user preferences are loaded
      _loadCustomLessons();
    } catch (e) {
      print('Error loading user preferences: $e');
      setState(() {
        _isLoading = false;
      });
      _loadCustomLessons();
    }
  }

  Future<void> _loadCustomLessons() async {
    setState(() => _isLoadingLessons = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance.collectionGroup('script-$userId').get();

      final customLessons = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;

        // Filter by category (Custom Lesson)
        String lessonCategory;
        if (data?.containsKey('category') == true && doc.get('category') != null && doc.get('category').toString().trim().isNotEmpty) {
          lessonCategory = doc.get('category');
        } else {
          lessonCategory = 'Custom Lesson';
        }

        // Filter by user's current target language
        final lessonTargetLanguage = data?['target_language']?.toString();

        return lessonCategory == 'Custom Lesson' && lessonTargetLanguage == targetLanguage;
      }).toList();

      // Sort by timestamp (newest first)
      customLessons.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

      if (mounted) {
        setState(() {
          _customLessons.clear();
          _customLessons.addAll(customLessons);
          _isLoadingLessons = false;
        });
      }
    } catch (e) {
      print('Error loading custom lessons: $e');
      setState(() => _isLoadingLessons = false);
    }
  }

  Future<void> _loadGenerationsRemaining() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        // Get current credits using the new credit service
        final currentCredits = await LessonCreditService.getCurrentCredits();

        // Check premium status
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final isPremium = userDoc.data()?['premium'] ?? false;

        // Get next credit reset date for premium users
        DateTime? nextReset;
        if (isPremium) {
          nextReset = await LessonCreditService.getNextCreditResetDate();
        }

        if (mounted) {
          setState(() {
            _isPremium = isPremium;
            _generationsRemaining = currentCredits;
            _nextCreditReset = nextReset;
          });
        }
      }
    } catch (e) {
      print('Error loading generations remaining: $e');
    }
  }

  Future<void> _handleLessonCreation(String topic, List<String> words) async {
    final loadingState = Provider.of<LoadingStateService>(context, listen: false);

    // Check credits first before setting loading state
    final hasCredit = await LessonCreditService.checkAndDeductCredit();
    if (!hasCredit) {
      // Show premium dialog and navigate to store if user wants to upgrade
      final shouldEnablePremium = await LessonService.showPremiumDialog(context);
      if (!shouldEnablePremium) {
        // Refresh the generations count
        _loadGenerationsRemaining();
        return;
      }
    }

    // Only set loading state if we have credits
    loadingState.setGeneratingLesson(true);

    try {
      await LessonService.createCustomLesson(
        context,
        topic,
        words,
        nativeLanguage,
        targetLanguage,
        languageLevel,
        (bool value) {
          // Update loading state from service
          if (mounted) {
            loadingState.setGeneratingLesson(value);
          }
        },
      );

      // Reload lessons when successful
      _loadCustomLessons();
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lesson: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        loadingState.setGeneratingLesson(false);
      }
      // Refresh the generations count after attempting to create a lesson
      _loadGenerationsRemaining();
    }
  }

  String _formatResetDate(DateTime resetDate) {
    final now = DateTime.now();
    final difference = resetDate.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
    } else {
      return 'Soon';
    }
  }

  void _showCustomLessonModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          margin: const EdgeInsets.only(top: 50),
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
            mainAxisSize: MainAxisSize.min,
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
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Generate Custom Lesson',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
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

              // Custom lesson form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: CustomLessonForm(
                    nativeLanguage: nativeLanguage,
                    targetLanguage: targetLanguage,
                    languageLevel: languageLevel,
                    isSmallScreen: MediaQuery.of(context).size.height < 700,
                    onLessonStarted: (topic, words) {
                      Navigator.pop(context); // Close the modal
                      _handleLessonCreation(topic, words); // Start lesson creation
                    },
                    onLessonCreated: () {
                      Navigator.pop(context);
                      _loadCustomLessons(); // Reload lessons
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<LoadingStateService>(
      builder: (context, loadingState, child) {
        final isGeneratingLesson = loadingState.isGeneratingLesson;

        return Scaffold(
          appBar: const AppBarWithDrawer(
            title: 'Custom Lessons',
          ),
          body: Stack(
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        // Sticky header
                        Container(
                          width: double.infinity,
                          color: colorScheme.surface,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            isSmallScreen ? 16 : 20,
                            16,
                            20,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.auto_awesome_rounded,
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
                                      'Create personalized lessons with your own topics and words',
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

                        // Scrollable content
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadCustomLessons,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Lessons section
                                  if (_isLoadingLessons)
                                    const Center(child: CircularProgressIndicator())
                                  else if (_customLessons.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: EmptyStateView(
                                        icon: Icons.auto_awesome_outlined,
                                        message: 'No custom lessons yet.\nTap the generate button to create your first lesson!',
                                        isSmallScreen: isSmallScreen,
                                      ),
                                    )
                                  else ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'Your Lessons (${_customLessons.length})',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...(_showAllLessons
                                        ? _customLessons.map((lesson) => LessonCard(
                                              audioFile: lesson,
                                              onReload: _loadCustomLessons,
                                              isSmallScreen: isSmallScreen,
                                            ))
                                        : _customLessons.take(10).map((lesson) => LessonCard(
                                              audioFile: lesson,
                                              onReload: _loadCustomLessons,
                                              isSmallScreen: isSmallScreen,
                                            ))),
                                    if (_customLessons.length > 10)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 12, bottom: 16),
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _showAllLessons = !_showAllLessons;
                                              });
                                            },
                                            icon: Icon(
                                              _showAllLessons ? Icons.expand_less : Icons.expand_more,
                                              color: colorScheme.primary,
                                              size: 18,
                                            ),
                                            label: Text(
                                              _showAllLessons ? 'Show Less' : 'View All ${_customLessons.length} Lessons',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                              side: BorderSide(
                                                color: colorScheme.primary,
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

                                  const SizedBox(height: 100), // Space for floating action button
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

              // Loading overlay to block interactions
              if (isGeneratingLesson)
                Container(
                  color: Colors.black.withOpacity(0.3),
                ),
            ],
          ),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 20, right: 4),
            child: FloatingActionButton.extended(
              onPressed: isGeneratingLesson
                  ? null
                  : _generationsRemaining <= 0
                      ? _isPremium
                          ? null // Disable button if premium user has no credits
                          : () async {
                              // Show premium dialog when no credits and not premium
                              await LessonService.showPremiumDialog(context);
                              _loadGenerationsRemaining(); // Refresh credits after dialog
                            }
                      : () => _showCustomLessonModal(context),
              backgroundColor: _generationsRemaining <= 0 ? Colors.grey.shade600 : colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 8,
              icon: isGeneratingLesson
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(_generationsRemaining <= 0 ? Icons.lock_rounded : Icons.auto_awesome_rounded, size: 22),
              label: isGeneratingLesson
                  ? const Text(
                      'Generating...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    )
                  : _generationsRemaining <= 0 && _isPremium
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No Credits Left',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            if (_nextCreditReset != null)
                              Text(
                                'Resets in ${_formatResetDate(_nextCreditReset!)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                          ],
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
                              _generationsRemaining <= 0 ? 'No credits remaining' : '$_generationsRemaining credits remaining',
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
        );
      },
    );
  }
}
