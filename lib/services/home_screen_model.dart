import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreenModel extends ChangeNotifier {
  List<DocumentSnapshot> selectedAudioFiles = [];
  List<dynamic> audioFileIds = [];
  ValueNotifier<List<dynamic>> audioFileIdsNotifier = ValueNotifier([]);

  void addAudioFile(DocumentSnapshot audioFile) {
    selectedAudioFiles.add(audioFile);
    audioFileIds.add({
      'docId': audioFile.id,
      'parentId': audioFile.reference.parent.parent!.id,
    });
    audioFileIdsNotifier.value = List.from(audioFileIds); // Update the notifier
    notifyListeners();
  }

  void removeAudioFile(DocumentSnapshot audioFile) {
    selectedAudioFiles.remove(audioFile);
    audioFileIds.removeWhere((file) =>
        file['docId'] == audioFile.id &&
        file['parentId'] == audioFile.reference.parent.parent!.id);
    audioFileIdsNotifier.value = List.from(audioFileIds); // Update the notifier
    notifyListeners();
  }

  Future<void> loadAudioFiles() async {
    final user = FirebaseAuth.instance.currentUser;
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final userDoc = await userDocRef.get();
    audioFileIds = userDoc.get('selectedAudioFiles') as List<dynamic>;
    audioFileIdsNotifier.value = audioFileIds;

    selectedAudioFiles = await Future.wait(audioFileIds.map((map) async {
      final scriptDocRef = FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(map['parentId'])
          .collection('scripts')
          .doc(map['docId']);
      final scriptDoc = await scriptDocRef.get();
      return scriptDoc;
    }));

    notifyListeners();
  }
}
