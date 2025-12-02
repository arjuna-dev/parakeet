import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:parakeet/services/daily_lesson_service.dart';
import 'package:parakeet/services/profile_service.dart';
import 'package:parakeet/widgets/home_screen/audio_waveform_widget.dart';
import 'package:parakeet/widgets/app_bar_with_drawer.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _progressData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userData = await ProfileService.fetchUserData();
    final progressData = await DailyLessonService.getDailyProgressData();
    
    setState(() {
      _userData = userData;
      _progressData = progressData;
      _isLoading = false;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final userName = _userData?['name'] ?? 'there';
    final targetLanguage = _userData?['target_language'] ?? 'French';
    final used = _progressData?['used'] ?? 0;
    final limit = _progressData?['limit'] ?? 4;
    final progress = limit > 0 ? used / limit : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: const AppBarWithDrawer(
        title: 'Home',
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top section with profile greeting
            _buildTopSection(context, userName, colorScheme),
            
            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    
                    // Daily Goal section
                    _buildDailyGoalSection(context, used, limit, progress, colorScheme),
                    
                    const SizedBox(height: 40),
                    
                    // Audio visualization
                    const Center(
                      child: AudioWaveformWidget(),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Lesson prompt
                    _buildLessonPrompt(context, targetLanguage, colorScheme),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    _buildActionButtons(context, colorScheme),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context, String userName, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          // Profile picture
          CircleAvatar(
            radius: 24,
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(
              Icons.person,
              color: colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          
          // Greeting
          Expanded(
            child: Text(
              '${_getGreeting()}, $userName!',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyGoalSection(
    BuildContext context,
    int used,
    int limit,
    double progress,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daily Goal',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Progress text
        Text(
          '$used/$limit lessons completed',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLessonPrompt(BuildContext context, String targetLanguage, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ready for your daily $targetLanguage lesson?',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Just 10 minutes to sound more like a local.',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    return Column(
      children: [
        // Start Daily Lesson button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/custom_lesson');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Start Daily Lesson',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Customize Topic button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/custom_lesson');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Customize Topic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

