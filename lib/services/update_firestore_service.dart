import 'dart:async';
import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UpdateFirestoreService extends ChangeNotifier {
  static UpdateFirestoreService? _instance;

  late Stream<QuerySnapshot> _stream;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  final Function(QuerySnapshot) updatePlaylist;
  final Function(QuerySnapshot) saveSnapshot;
  final Function updateTrack;
  Queue<QuerySnapshot> queue = Queue<QuerySnapshot>();
  bool isUpdating = false;
  bool _isDisposed = false;
  String? _documentID;

  UpdateFirestoreService._privateConstructor(this.updatePlaylist, this.updateTrack, this.saveSnapshot);

  static UpdateFirestoreService getInstance(
      String documentID,
      bool generating,
      String lessonType,
      Function(QuerySnapshot) updatePlaylist, // Explicit type
      Function updateTrack,
      Function(QuerySnapshot) saveSnapshot) {
    if (_instance == null || _instance!._documentID != documentID) {
      _instance?._streamSubscription?.cancel();
      _instance = UpdateFirestoreService._privateConstructor(
          updatePlaylist, updateTrack, saveSnapshot);
    }
    _instance!._initializeStream(documentID, generating, lessonType);
    return _instance!;
  }

  void _initializeStream(String documentID, bool generating, String lessonType) {
    _documentID = documentID;
    _isDisposed = false;
    _streamSubscription?.cancel();
    queue.clear();
    final collectionName =
        lessonType == 'grammar' ? 'only_target_sentences' : 'all_breakdowns';
    _stream = FirebaseFirestore.instance
        .collection('chatGPT_responses')
        .doc(documentID)
        .collection(collectionName)
        .snapshots();
    _streamSubscription = _stream.listen((snapshot) {
      if (_isDisposed) return;
      queue.add(snapshot);
      processQueue(updateTrack, generating);
    });
  }

  Future<void> processQueue(updateTrack, generating) async {
    if (_isDisposed) return;
    if (!isUpdating && queue.isNotEmpty) {
      isUpdating = true;
      QuerySnapshot snapshot = queue.removeFirst();
      await updatePlaylist(snapshot);
      if (_isDisposed) return;
      saveSnapshot(snapshot);
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
    _isDisposed = true;
    _streamSubscription?.cancel();
    _instance = null;
    queue.clear();
    super.dispose();
  }

  /// Static method to force cleanup of any shared resources
  static void forceCleanup() {
    if (_instance != null) {
      _instance!._isDisposed = true;
      _instance!._streamSubscription?.cancel();
      _instance!.queue.clear();
      _instance = null;
    }
  }
}
