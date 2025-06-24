import 'package:flutter/material.dart';

class LoadingStateService extends ChangeNotifier {
  bool _isGeneratingLesson = false;

  bool get isGeneratingLesson => _isGeneratingLesson;

  void setGeneratingLesson(bool isGenerating) {
    _isGeneratingLesson = isGenerating;
    notifyListeners();
  }
}
