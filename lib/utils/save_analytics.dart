import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsAction {
  final String action;
  final DateTime timestamp;
  final String data;

  AnalyticsAction({
    required this.action,
    required this.timestamp,
    this.data = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'timestamp': timestamp,
      'data': data,
    };
  }

  factory AnalyticsAction.fromMap(Map<String, dynamic> map) {
    return AnalyticsAction(
      action: map['action'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      data: map['data'] as String? ?? '',
    );
  }
}

class AnalyticsManager {
  final String userId;

  AnalyticsManager(this.userId);

  /// Store a single action with timestamp to Firebase. Data is optional.
  Future<void> storeAction(String action, [String data = '']) async {
    final analyticsAction = AnalyticsAction(
      action: action,
      timestamp: DateTime.now(),
      data: data,
    );

    // Create a new document for each action in the user's analytics subcollection
    await FirebaseFirestore.instance.collection('users').doc(userId).collection('analytics').add(analyticsAction.toMap());
  }
}
