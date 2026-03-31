import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Remembers recently used lesson topics per user + target language so random
/// picks and APIs can avoid immediate repeats.
class RecentLessonTopicsService {
  RecentLessonTopicsService._();

  static const int _maxStored = 80;
  static const String _prefsKeyPrefix = 'recent_lesson_topics_v1_';
  static const String conversationLessonType = 'conversation';
  static const String grammarLessonType = 'grammar';

  static String _storageKey(
    String userId,
    String targetLanguage,
    String lessonType,
  ) =>
      '$_prefsKeyPrefix${userId}_${targetLanguage.hashCode}_$lessonType';

  static String normalize(String topic) => topic.trim().toLowerCase();

  static Future<List<String>> getRecentTopics(
      String userId, String targetLanguage,
      {String lessonType = conversationLessonType}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_storageKey(userId, targetLanguage, lessonType));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearRecentTopics(String userId, String targetLanguage,
      {String lessonType = conversationLessonType}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey(userId, targetLanguage, lessonType));
  }

  /// Call after a lesson successfully starts with the scenario / topic string.
  static Future<void> recordTopic(
      String userId, String targetLanguage, String topic,
      {String lessonType = conversationLessonType}) async {
    final t = topic.trim();
    if (t.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey(userId, targetLanguage, lessonType);
    var recent =
        await getRecentTopics(userId, targetLanguage, lessonType: lessonType);
    final norm = normalize(t);
    recent.removeWhere((x) => normalize(x) == norm);
    recent.insert(0, t);
    if (recent.length > _maxStored) {
      recent = recent.sublist(0, _maxStored);
    }
    await prefs.setString(key, jsonEncode(recent));
  }

  /// Picks from [allKeys] avoiding topics in storage; if all are used, clears
  /// history and picks randomly so the user can cycle through scenarios again.
  static Future<String> pickUnusedScenarioKey(
      List<String> allKeys, String userId, String targetLanguage,
      {String lessonType = conversationLessonType}) async {
    if (allKeys.isEmpty) {
      throw Exception('No scenarios available');
    }
    final recent =
        await getRecentTopics(userId, targetLanguage, lessonType: lessonType);
    final used = recent.map(normalize).toSet();
    var available = allKeys.where((k) => !used.contains(normalize(k))).toList();
    if (available.isEmpty) {
      await clearRecentTopics(userId, targetLanguage, lessonType: lessonType);
      available = allKeys;
    }
    return available[Random().nextInt(available.length)];
  }
}
