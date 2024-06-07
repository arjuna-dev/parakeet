import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreenModel extends ChangeNotifier {
  List<DocumentSnapshot> favoriteAudioFiles = [];
  List<DocumentSnapshot> nowPlayingFiles = [];
  List<dynamic> favoriteAudioFileIds = [];
  List<dynamic> nowPlayingIds = [];
  ValueNotifier<List<dynamic>> favoriteAudioFileIdsNotifier = ValueNotifier([]);
  ValueNotifier<List<dynamic>> nowPlayingIdsNotifier = ValueNotifier([]);
  final user = FirebaseAuth.instance.currentUser;

  void addAudioFile(DocumentSnapshot audioFile) {
    favoriteAudioFiles.add(audioFile);
    favoriteAudioFileIds.add({
      'docId': audioFile.id,
      'parentId': audioFile.reference.parent.parent!.id,
    });
    favoriteAudioFileIdsNotifier.value =
        List.from(favoriteAudioFileIds); // Update the notifier
    notifyListeners();
  }

  void removeAudioFile(DocumentSnapshot audioFile) {
    favoriteAudioFiles.remove(audioFile);
    favoriteAudioFileIds.removeWhere((file) =>
        file['docId'] == audioFile.id &&
        file['parentId'] == audioFile.reference.parent.parent!.id);
    favoriteAudioFileIdsNotifier.value =
        List.from(favoriteAudioFileIds); // Update the notifier
    notifyListeners();
  }

  Future<void> loadAudioFiles() async {
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user!.uid);
    final userDoc = await userDocRef.get();
    if (userDoc.data()!.containsKey('favoriteAudioFiles')) {
      favoriteAudioFileIds =
          userDoc.get('favoriteAudioFiles') as List<dynamic>? ?? [];
    }

    favoriteAudioFileIdsNotifier.value = favoriteAudioFileIds;

    favoriteAudioFiles =
        await Future.wait(favoriteAudioFileIds.map((map) async {
      final scriptDocRef = FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(map['parentId'])
          .collection('script')
          .doc(map['docId']);
      final scriptDoc = await scriptDocRef.get();
      return scriptDoc;
    }));

    notifyListeners();
  }

  Future<void> loadNowPlayingFromPreference() async {
    final prefs = await SharedPreferences.getInstance();
    nowPlayingIds = prefs.getStringList('now_playing_${user!.uid}')!;

    nowPlayingIdsNotifier.value = nowPlayingIds;

    nowPlayingFiles = await Future.wait(nowPlayingIds.map((id) async {
      final scriptCollectionRef = FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(id)
          .collection('script');
      final scriptDocs = await scriptCollectionRef.get();
      if (scriptDocs.docs.isNotEmpty) {
        return scriptDocs.docs.first;
      } else {
        throw Exception('No document found in the scripts collection');
      }
    }));

    notifyListeners();
  }
}
