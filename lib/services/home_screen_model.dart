import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreenModel extends ChangeNotifier {
  bool _isDisposed = false;
  List<DocumentSnapshot> favoriteAudioFiles = [];
  List<DocumentSnapshot> nowPlayingFiles = [];
  List<dynamic> favoriteAudioFileIds = [];
  List<dynamic> nowPlayingIds = [];
  ValueNotifier<List<dynamic>> favoriteAudioFileIdsNotifier = ValueNotifier([]);
  ValueNotifier<List<dynamic>> nowPlayingIdsNotifier = ValueNotifier([]);
  final user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void addAudioFile(DocumentSnapshot audioFile) {
    favoriteAudioFiles.add(audioFile);
    favoriteAudioFileIds.add({
      'docId': audioFile.id,
      'parentId': audioFile.reference.parent.parent!.id,
    });
    favoriteAudioFileIdsNotifier.value =
        List.from(favoriteAudioFileIds); // Update the notifier
    safeNotifyListeners();
  }

  void removeAudioFile(DocumentSnapshot audioFile) {
    favoriteAudioFiles.remove(audioFile);
    favoriteAudioFileIds.removeWhere((file) =>
        file['docId'] == audioFile.id &&
        file['parentId'] == audioFile.reference.parent.parent!.id);
    favoriteAudioFileIdsNotifier.value =
        List.from(favoriteAudioFileIds); // Update the notifier
    safeNotifyListeners();
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
          .collection('script-${user!.uid}')
          .doc(map['docId']);
      final scriptDoc = await scriptDocRef.get();
      return scriptDoc;
    }));

    safeNotifyListeners();
  }

  Future<void> loadNowPlayingFromPreference() async {
    final prefs = await SharedPreferences.getInstance();
    nowPlayingIds = prefs.getStringList('now_playing_${user!.uid}')!;
    print(nowPlayingIds);

    nowPlayingIdsNotifier.value = nowPlayingIds;

    nowPlayingFiles = await Future.wait(nowPlayingIds.map((id) async {
      final scriptCollectionRef = FirebaseFirestore.instance
          .collection('chatGPT_responses')
          .doc(id)
          .collection('script-${user!.uid}');
      final scriptDocs = await scriptCollectionRef.get();
      if (scriptDocs.docs.isNotEmpty) {
        return scriptDocs.docs.first;
      } else {
        throw Exception('No document found in the scripts collection');
      }
    }));

    safeNotifyListeners();
  }
}
