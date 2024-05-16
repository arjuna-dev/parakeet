import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HomeScreenModel extends ChangeNotifier {
  List<DocumentSnapshot> selectedAudioFiles = [];

  void addAudioFile(DocumentSnapshot audioFile) {
    selectedAudioFiles.add(audioFile);
    notifyListeners();
  }
}
