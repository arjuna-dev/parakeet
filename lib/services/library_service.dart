import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class LibraryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Load documents from Firestore
  static Future<Map<String, dynamic>> loadDocuments(HomeScreenModel model) async {
    final String userId = FirebaseAuth.instance.currentUser!.uid;
    final snapshot = await _firestore.collectionGroup('script-$userId').get();

    Map<String, bool> newFavorites = {};
    Map<String, List<DocumentSnapshot>> newCategorizedDocuments = {};
    List<DocumentSnapshot> allDocuments = [];

    // Default category for lessons without a category
    const String defaultCategory = "Custom Lesson";

    for (var doc in snapshot.docs) {
      String parentId = doc.reference.parent.parent!.id;
      String docId = doc.reference.id;
      String key = '$parentId-$docId';
      newFavorites[key] = model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId);

      // Get category from document or use default
      // Handle cases where category is null, empty, or doesn't exist
      String category;
      if ((doc.data()).containsKey('category') && doc.get('category') != null && doc.get('category').toString().trim().isNotEmpty) {
        category = doc.get('category');
      } else {
        category = defaultCategory;
      }

      if (!newCategorizedDocuments.containsKey(category)) {
        newCategorizedDocuments[category] = [];
      }

      newCategorizedDocuments[category]!.add(doc);
      allDocuments.add(doc);
    }

    // Sort documents within each category by timestamp
    newCategorizedDocuments.forEach((category, docs) {
      docs.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));
    });

    // Initialize expanded state for categories
    Map<String, bool> newExpandedCategories = {};
    for (var category in newCategorizedDocuments.keys) {
      newExpandedCategories[category] = false; // Default to collapsed
    }

    // Sort all documents by timestamp
    allDocuments.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));

    return {
      'documents': allDocuments,
      'favorites': newFavorites,
      'categorizedDocuments': newCategorizedDocuments,
      'expandedCategories': newExpandedCategories,
    };
  }

  // Toggle favorite status
  static Future<void> toggleFavorite(DocumentSnapshot document, HomeScreenModel model, Map<String, bool> localFavorites, Function(Map<String, bool>) updateFavorites) async {
    final user = FirebaseAuth.instance.currentUser;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    String parentId = document.reference.parent.parent!.id;
    String docId = document.reference.id;
    String key = '$parentId-$docId';

    bool newState = !(localFavorites[key] ?? false);

    // Update local state
    Map<String, bool> updatedFavorites = Map<String, bool>.from(localFavorites);
    updatedFavorites[key] = newState;
    updateFavorites(updatedFavorites);

    if (!newState) {
      model.removeAudioFile(document);
      await userDocRef.update({
        'favoriteAudioFiles': FieldValue.arrayRemove([
          {'parentId': parentId, 'docId': docId}
        ])
      });
    } else {
      model.addAudioFile(document);
      await userDocRef.set({
        'favoriteAudioFiles': FieldValue.arrayUnion([
          {'parentId': parentId, 'docId': docId}
        ])
      }, SetOptions(merge: true));
    }
  }

  // Delete document
  static Future<void> deleteDocument(DocumentSnapshot document, HomeScreenModel model) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final String userId = user.uid;
    final String parentId = document.reference.parent.parent!.id;
    final String docId = document.reference.id;

    // 1. Remove from favorites if it's a favorite
    if (model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId)) {
      model.removeAudioFile(document);
      await _firestore.collection('users').doc(userId).update({
        'favoriteAudioFiles': FieldValue.arrayRemove([
          {'parentId': parentId, 'docId': docId}
        ])
      });
    }

    // 2. Remove from "now playing" list in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedPosition_${parentId}_$userId');
    await prefs.remove('savedTrackName_${parentId}_$userId');
    await prefs.remove("now_playing_${parentId}_$userId");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_$userId");
    if (nowPlayingList != null) {
      nowPlayingList.remove(parentId);
      await prefs.setStringList("now_playing_$userId", nowPlayingList);
    }

    // 3. Delete the audio file and document by calling cloud function
    deleteFromStorageAndFirestore(parentId, userId);
  }

  // Delete from cloud storage
  static void deleteFromStorageAndFirestore(String documentId, String userId) {
    http.post(
      Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/delete_audio_file'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Access-Control-Allow-Origin": "*", // Required for CORS support to work
      },
      body: jsonEncode(<String, String>{
        "document_id": documentId,
        "user_id": userId,
      }),
    );
  }
}
