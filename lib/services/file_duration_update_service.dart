import 'dart:async';
import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FileDurationUpdate extends ChangeNotifier {
  static FileDurationUpdate? _instance;

  late Stream<QuerySnapshot> _stream;
  StreamSubscription<QuerySnapshot>? _streamSubscription;
  Queue<QuerySnapshot> queue = Queue<QuerySnapshot>();
  bool isUpdating = false;
  Function calculateTotalDurationAndUpdateTrackDurations;

  FileDurationUpdate._privateConstructor(this.calculateTotalDurationAndUpdateTrackDurations);

  static FileDurationUpdate getInstance(String documentID, Function calculateTotalDurationAndUpdateTrackDurations) {
    _instance ??= FileDurationUpdate._privateConstructor(calculateTotalDurationAndUpdateTrackDurations);
    _instance!._initializeStream(documentID);
    return _instance!;
  }

  void _initializeStream(String documentID) {
    _stream = FirebaseFirestore.instance.collection('chatGPT_responses').doc(documentID).collection('file_durations').snapshots();
    _streamSubscription = _stream.listen((snapshot) {
      queue.add(snapshot);
      processQueue();
    });
  }

  Future<void> processQueue() async {
    if (!isUpdating && queue.isNotEmpty) {
      isUpdating = true;
      await calculateTotalDurationAndUpdateTrackDurations(queue.removeFirst());
      isUpdating = false;
      processQueue();
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

  /// Static method to force cleanup of any shared resources
  static void forceCleanup() {
    if (_instance != null) {
      _instance!._streamSubscription?.cancel();
      _instance!.queue.clear();
      _instance = null;
    }
  }
}
