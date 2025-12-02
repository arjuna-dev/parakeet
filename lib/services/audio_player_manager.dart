import 'package:flutter/material.dart';
import 'package:parakeet/services/audio_player_service.dart';

class LessonData {
  final String documentID;
  final List<dynamic>? dialogue;
  final String category;
  final String targetLanguage;
  final String nativeLanguage;
  final String languageLevel;
  final String userID;
  final String title;
  final String scriptDocumentId;
  final bool generating;
  final List<dynamic>? wordsToRepeat;
  final int numberOfTurns;

  LessonData({
    required this.documentID,
    this.dialogue,
    required this.category,
    required this.targetLanguage,
    required this.nativeLanguage,
    required this.languageLevel,
    required this.userID,
    required this.title,
    required this.scriptDocumentId,
    required this.generating,
    this.wordsToRepeat,
    required this.numberOfTurns,
  });
}

class AudioPlayerManager extends ChangeNotifier {
  AudioPlayerService? _service;
  LessonData? _currentLesson;
  bool _isExpanded = false;
  bool _isVisible = false;

  AudioPlayerService? get service => _service;
  LessonData? get currentLesson => _currentLesson;
  bool get isExpanded => _isExpanded;
  bool get isVisible => _isVisible;

  void playLesson(LessonData lesson) {
    // If it's a different lesson, we need to completely reset
    if (_currentLesson?.documentID != lesson.documentID) {
      // First, close the player completely to destroy the AudioPlayerScreen widget
      if (_isVisible) {
        _isVisible = false;
        _isExpanded = false;
        notifyListeners();
      }

      // Stop and dispose the old service
      _service?.stop();
      _service?.dispose();

      // Create a new service for the new lesson
      _service = AudioPlayerService(
        documentID: lesson.documentID,
        userID: lesson.userID,
        hasPremium: false, // TODO: Check premium status properly
      );
      _currentLesson = lesson;

      // Small delay to ensure the old widget is destroyed before showing the new one
      Future.delayed(const Duration(milliseconds: 100), () {
        _isVisible = true;
        _isExpanded = true;
        notifyListeners();
      });
    } else {
      // Same lesson, just expand if collapsed
      _isVisible = true;
      _isExpanded = true;
      notifyListeners();
    }
  }

  void expand() {
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    _isExpanded = false;
    notifyListeners();
  }

  void close() {
    _isVisible = false;
    _isExpanded = false;
    _service?.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }
}
