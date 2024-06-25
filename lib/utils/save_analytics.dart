import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsData {
  DateTime timestamp;
  String action; // 'play', 'pause', or 'completed'
  int count;
  List<DateTime> timestamps;

  AnalyticsData({
    required this.timestamp,
    required this.action,
    this.count = 1,
    required this.timestamps,
  });

  // Method to update the analytics data
  void updateData(DateTime newTimestamp) {
    timestamp = newTimestamp;
    count += 1;
    timestamps.add(newTimestamp);
  }

  Map<String, dynamic> toMap() {
    return {
      action: {
        'timestamp': timestamp,
        'count': count,
        'timestamps': timestamps.map((ts) => ts.toIso8601String()).toList(),
      }
    };
  }
}

class AnalyticsManager {
  Map<String, AnalyticsData> analytics = {};
  final String userId;
  final String documentId;

  AnalyticsManager(this.userId, this.documentId);

  void loadAnalyticsFromFirebase() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc(documentId)
        .get()
        .then((DocumentSnapshot<Map<String, dynamic>> snapshot) {
      if (snapshot.exists) {
        _loadAnalytics(snapshot.data()!);
      }
    });
  }

  void _loadAnalytics(Map<String, dynamic> data) {
    print(data);
    data.forEach((key, value) {
      print(value['timestamp']);
      analytics[key] = AnalyticsData(
          timestamp: (value['timestamp'] as Timestamp).toDate(),
          action: key,
          count: value['count'],
          timestamps: List<DateTime>.from(
            value['timestamps'].map((ts) => DateTime.parse(ts as String)),
          ));
    });
  }

  void storeAnalytics(String fileId, String action) {
    DateTime currentTimestamp = DateTime.now();

    if (analytics.containsKey(action)) {
      analytics[action]!.updateData(currentTimestamp);
    } else {
      analytics[action] = AnalyticsData(
        timestamp: currentTimestamp,
        action: action,
        timestamps: [currentTimestamp],
      );
    }
    // Save to Firebase
    _saveToFirebase(fileId, action);
  }

  Future<void> _saveToFirebase(String fileId, String action) async {
    AnalyticsData data = analytics[action]!;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc(fileId)
        .set(data.toMap(), SetOptions(merge: true));
  }

  Map<String, AnalyticsData> getAnalytics() {
    return analytics;
  }
}
