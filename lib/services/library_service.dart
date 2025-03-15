import 'dart:convert';
import 'package:flutter/material.dart';
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
    const String defaultCategory = "Custom Lessons";

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
  static Future<void> deleteDocument(DocumentSnapshot document, HomeScreenModel model, List<DocumentSnapshot> documents, Map<String, List<DocumentSnapshot>> categorizedDocuments, Map<String, bool> expandedCategories,
      Function(List<DocumentSnapshot>, Map<String, List<DocumentSnapshot>>, Map<String, bool>) updateState) async {
    // Find document in the main documents list
    final index = documents.indexOf(document);
    List<DocumentSnapshot> updatedDocuments = List<DocumentSnapshot>.from(documents);
    Map<String, List<DocumentSnapshot>> updatedCategorizedDocuments = Map<String, List<DocumentSnapshot>>.from(categorizedDocuments);
    Map<String, bool> updatedExpandedCategories = Map<String, bool>.from(expandedCategories);

    // Find document in categorized documents
    String? categoryToUpdate;
    int docIndex = -1;

    for (var entry in categorizedDocuments.entries) {
      final categoryDocs = entry.value;
      final idx = categoryDocs.indexOf(document);
      if (idx != -1) {
        categoryToUpdate = entry.key;
        docIndex = idx;
        break;
      }
    }

    // Update state only if document was found
    // Remove from main documents list if found
    if (index != -1) {
      updatedDocuments.removeAt(index);
    }

    // Remove from categorized documents if found
    if (categoryToUpdate != null && docIndex != -1) {
      updatedCategorizedDocuments[categoryToUpdate]!.removeAt(docIndex);

      // Remove category if empty
      if (updatedCategorizedDocuments[categoryToUpdate]!.isEmpty) {
        updatedCategorizedDocuments.remove(categoryToUpdate);
        updatedExpandedCategories.remove(categoryToUpdate);
      }
    }

    // Update state with modified collections
    updateState(updatedDocuments, updatedCategorizedDocuments, updatedExpandedCategories);

    // Delete from Firestore regardless of whether it was found in local lists
    await _firestore.runTransaction((Transaction myTransaction) async {
      myTransaction.delete(document.reference);
    });

    final user = FirebaseAuth.instance.currentUser;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    String parentId = document.reference.parent.parent!.id;
    String docId = document.reference.id;

    if (model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId)) {
      model.removeAudioFile(document);
      await userDocRef.update({
        'favoriteAudioFiles': FieldValue.arrayRemove([
          {'parentId': parentId, 'docId': docId}
        ])
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('savedPosition_${parentId}_${user.uid}');
    await prefs.remove('savedTrackIndex_${parentId}_${user.uid}');
    await prefs.remove("now_playing_${parentId}_${user.uid}");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_${user.uid}");
    if (nowPlayingList != null) {
      nowPlayingList.remove(parentId);
      await prefs.setStringList("now_playing_${user.uid}", nowPlayingList);
    }

    deleteFromCloudStorage(parentId);
  }

  // Delete from cloud storage
  static void deleteFromCloudStorage(String documentId) {
    http.post(
      Uri.parse('https://europe-west1-noble-descent-420612.cloudfunctions.net/delete_audio_file'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        "Access-Control-Allow-Origin": "*", // Required for CORS support to work
      },
      body: jsonEncode(<String, String>{
        "document_id": documentId,
      }),
    );
  }
}
