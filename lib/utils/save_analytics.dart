import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsData {
  DateTime timestamp;
  String fileId;
  String action; // 'play', 'pause', or 'completed'
  int count;
  List<DateTime> timestamps;

  AnalyticsData({
    required this.timestamp,
    required this.fileId,
    required this.action,
    this.count = 1,
    required this.timestamps,
  });

  // Method to update the analytics data
  void updateData(DateTime newTimestamp) {
    count += 1;
    timestamps.add(newTimestamp);
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'fileId': fileId,
      'action': action,
      'count': count,
      'timestamps': timestamps.map((ts) => ts.toIso8601String()).toList(),
    };
  }
}

class AnalyticsManager {
  Map<String, AnalyticsData> analytics = {};
  final String userId;

  AnalyticsManager(this.userId);

  void storeAnalytics(String fileId, String action) {
    DateTime currentTimestamp = DateTime.now();
    String key = "$fileId-$action";

    if (analytics.containsKey(key)) {
      analytics[key]!.updateData(currentTimestamp);
    } else {
      analytics[key] = AnalyticsData(
        timestamp: currentTimestamp,
        fileId: fileId,
        action: action,
        timestamps: [currentTimestamp],
      );
    }
    // Save to Firebase
    _saveToFirebase(fileId, action);
  }

  Future<void> _saveToFirebase(String fileId, String action) async {
    String key = "$fileId-$action";
    AnalyticsData data = analytics[key]!;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('analytics')
        .doc(key)
        .set(data.toMap(), SetOptions(merge: true));
  }

  Map<String, AnalyticsData> getAnalytics() {
    return analytics;
  }
}
