import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UpdateFirestoreService extends ChangeNotifier {
  static UpdateFirestoreService? _instance;

  late Stream<QuerySnapshot> _stream;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Function updatePlaylist;
  Function updateTrack;
  Queue<QuerySnapshot> queue = Queue<QuerySnapshot>();
  bool isUpdating = false;

  UpdateFirestoreService._privateConstructor(
      this.updatePlaylist, this.updateTrack);

  static UpdateFirestoreService getInstance(String documentID, bool generating,
      Function updatePlaylist, Function updateTrack) {
    _instance ??=
        UpdateFirestoreService._privateConstructor(updatePlaylist, updateTrack);
    _instance!._initializeStream(documentID, generating);
    return _instance!;
  }

  void _initializeStream(String documentID, bool generating) {
    _stream = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection('all_breakdowns')
        .snapshots();
    _streamSubscription = _stream.listen((snapshot) {
      queue.add(snapshot);
      processQueue(updateTrack, generating);
    });
  }

  Future<void> processQueue(updateTrack, generating) async {
    if (!isUpdating && queue.isNotEmpty) {
      isUpdating = true;
      await updatePlaylist(queue.removeFirst());
      isUpdating = false;
      if (queue.isEmpty && generating) {
        updateTrack();
      }
      processQueue(updateTrack, generating);
    }
  }

  Stream<QuerySnapshot> get stream => _stream;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _instance = null;
    queue.clear();
    super.dispose();
  }
}
