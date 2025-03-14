import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/screens/audio_player_screen.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  Map<String, bool> localFavorites = {};
  List<DocumentSnapshot> documents = [];
  bool isLoading = true;
  Map<String, List<DocumentSnapshot>> categorizedDocuments = {};
  Map<String, bool> expandedCategories = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Provider.of<HomeScreenModel>(context, listen: false).loadAudioFiles();
    _loadDocuments();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateFavorites();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateFavorites();
  }

  void _updateFavorites() {
    if (documents.isEmpty) return;

    final model = Provider.of<HomeScreenModel>(context, listen: false);
    Map<String, bool> newFavorites = {};

    for (var doc in documents) {
      String parentId = doc.reference.parent.parent!.id;
      String docId = doc.reference.id;
      String key = '$parentId-$docId';
      newFavorites[key] = model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId);
    }

    if (mapEquals(localFavorites, newFavorites) == false) {
      setState(() {
        localFavorites = newFavorites;
      });
    }
  }

  Future<void> _loadDocuments() async {
    final snapshot = await _firestore.collectionGroup('script-$userId').get();
    final model = Provider.of<HomeScreenModel>(context, listen: false);

    Map<String, bool> newFavorites = {};
    Map<String, List<DocumentSnapshot>> newCategorizedDocuments = {};

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

    setState(() {
      documents = snapshot.docs;
      documents.sort((a, b) => b.get('timestamp').compareTo(a.get('timestamp')));
      localFavorites = newFavorites;
      categorizedDocuments = newCategorizedDocuments;
      expandedCategories = newExpandedCategories;
      isLoading = false;
    });
  }

  Future<void> toggleFavorite(DocumentSnapshot document, HomeScreenModel model) async {
    final user = FirebaseAuth.instance.currentUser;
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
    String parentId = document.reference.parent.parent!.id;
    String docId = document.reference.id;
    String key = '$parentId-$docId';

    bool newState = !(localFavorites[key] ?? false);
    setState(() {
      localFavorites[key] = newState;
    });

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

  Future<void> deleteDocument(DocumentSnapshot document, HomeScreenModel model) async {
    // Find document in the main documents list
    final index = documents.indexOf(document);

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
    setState(() {
      // Remove from main documents list if found
      if (index != -1) {
        documents.removeAt(index);
      }

      // Remove from categorized documents if found
      if (categoryToUpdate != null && docIndex != -1) {
        categorizedDocuments[categoryToUpdate]!.removeAt(docIndex);

        // Remove category if empty
        if (categorizedDocuments[categoryToUpdate]!.isEmpty) {
          categorizedDocuments.remove(categoryToUpdate);
          expandedCategories.remove(categoryToUpdate);
        }
      }
    });

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
    await prefs.remove('savedPosition_${parentId}_$userId');
    await prefs.remove('savedTrackIndex_${parentId}_$userId');
    await prefs.remove("now_playing_${parentId}_$userId");

    List<String>? nowPlayingList = prefs.getStringList("now_playing_$userId");
    if (nowPlayingList != null) {
      nowPlayingList.remove(parentId);
      await prefs.setStringList("now_playing_$userId", nowPlayingList);
    }

    deleteFromCloudStorage(parentId);
  }

  bool isFavorite(DocumentSnapshot document, HomeScreenModel model) {
    String parentId = document.reference.parent.parent!.id;
    String docId = document.reference.id;
    String key = '$parentId-$docId';

    if (!localFavorites.containsKey(key)) {
      localFavorites[key] = model.favoriteAudioFileIds.any((file) => file['docId'] == docId && file['parentId'] == parentId);
    }
    return localFavorites[key]!;
  }

  void deleteFromCloudStorage(documentId) {
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

  void toggleCategoryExpansion(String category) {
    setState(() {
      expandedCategories[category] = !(expandedCategories[category] ?? false);
    });
  }

  void toggleAllCategories() {
    // Check if all categories are expanded
    bool allExpanded = categorizedDocuments.keys.every((category) => expandedCategories[category] == true);

    // Toggle all to the opposite state
    setState(() {
      for (var category in categorizedDocuments.keys) {
        expandedCategories[category] = !allExpanded;
      }
    });
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case 'At the Coffee Shop':
        return Icons.coffee;
      case 'Weather Talk':
        return Icons.wb_sunny;
      case 'In the Supermarket':
        return Icons.shopping_cart;
      case 'Asking for Directions':
        return Icons.map;
      case 'Making Small Talk':
        return Icons.chat_bubble;
      case 'At the Airport':
        return Icons.flight;
      case 'At the Restaurant':
        return Icons.restaurant;
      case 'At the Hotel':
        return Icons.hotel;
      case 'At the Doctor\'s Office':
        return Icons.local_hospital;
      case 'Public Transportation':
        return Icons.directions_bus;
      case 'Shopping for Clothes':
        return Icons.shopping_bag;
      case 'At the Gym':
        return Icons.fitness_center;
      case 'At the Bank':
        return Icons.account_balance;
      case 'At the Post Office':
        return Icons.local_post_office;
      case 'At the Pharmacy':
        return Icons.local_pharmacy;
      case 'At the Park':
        return Icons.park;
      case 'At the Beach':
        return Icons.beach_access;
      case 'At the Library':
        return Icons.library_books;
      case 'At the Cinema':
        return Icons.movie;
      case 'At the Hair Salon':
        return Icons.content_cut;
      case 'Custom Lessons':
        return Icons.create;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final padding = isSmallScreen ? 8.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Library',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: <Widget>[
          if (documents.isNotEmpty)
            IconButton(
              icon: Icon(
                categorizedDocuments.keys.every((category) => expandedCategories[category] == true) ? Icons.unfold_less : Icons.unfold_more,
                color: colorScheme.primary,
              ),
              tooltip: categorizedDocuments.keys.every((category) => expandedCategories[category] == true) ? 'Collapse all' : 'Expand all',
              onPressed: toggleAllCategories,
            ),
          buildProfilePopupMenu(context),
        ],
      ),
      body: Container(
        child: Consumer<HomeScreenModel>(
          builder: (context, model, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateFavorites();
            });

            if (isLoading) {
              return Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.horizontalPadding.left,
                vertical: padding,
              ),
              child: documents.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.library_music_outlined,
                            size: isSmallScreen ? 32 : 48,
                            color: colorScheme.primary.withOpacity(0.7),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: isSmallScreen ? 14 : 16,
                              ),
                              children: <TextSpan>[
                                const TextSpan(text: 'Your library is empty. '),
                                TextSpan(
                                  text: 'Create your first lesson 🎵',
                                  style: TextStyle(
                                    decoration: TextDecoration.underline,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      Navigator.pushReplacementNamed(context, '/create_lesson');
                                    },
                                ),
                                const TextSpan(text: ' to fill it with your audio lessons!'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                      itemCount: categorizedDocuments.length,
                      itemBuilder: (context, index) {
                        final category = categorizedDocuments.keys.elementAt(index);
                        final categoryDocs = categorizedDocuments[category]!;
                        final isExpanded = expandedCategories[category] ?? true;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category header
                            InkWell(
                              onTap: () => toggleCategoryExpansion(category),
                              child: Container(
                                margin: EdgeInsets.only(
                                  bottom: isSmallScreen ? 8 : 12,
                                  top: index > 0 ? (isSmallScreen ? 16 : 24) : 0,
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: isSmallScreen ? 8 : 12,
                                  horizontal: isSmallScreen ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      getCategoryIcon(category),
                                      color: colorScheme.primary,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Expanded(
                                      child: Text(
                                        category,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isSmallScreen ? 16 : 18,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${categoryDocs.length} ${categoryDocs.length == 1 ? 'lesson' : 'lessons'}',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14,
                                        color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: colorScheme.primary,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Category lessons (collapsible)
                            if (isExpanded)
                              ...categoryDocs
                                  .map((document) => Card(
                                        elevation: 2,
                                        margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: colorScheme.surfaceContainerHighest.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: isSmallScreen ? 12 : 16,
                                            vertical: isSmallScreen ? 8 : 12,
                                          ),
                                          title: Text(
                                            document.get('title'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen ? 15 : 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.translate, size: 16, color: colorScheme.primary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      "${(document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)'} → ${document.get('target_language')}",
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 12 : 13,
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.stairs, size: 16, color: colorScheme.primary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      "${document.get('language_level')}",
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 12 : 13,
                                                        color: colorScheme.onSurfaceVariant,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          leading: Container(
                                            width: isSmallScreen ? 40 : 48,
                                            height: isSmallScreen ? 40 : 48,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                isFavorite(document, model) ? Icons.favorite : Icons.favorite_border,
                                                color: colorScheme.primary,
                                                size: isSmallScreen ? 24 : 28,
                                              ),
                                              onPressed: () => toggleFavorite(document, model),
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete,
                                                  color: colorScheme.error,
                                                  size: isSmallScreen ? 22 : 24,
                                                ),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (BuildContext context) {
                                                      return AlertDialog(
                                                        title: const Text('Confirmation'),
                                                        content: const Text('Are you sure you want to delete this audio?'),
                                                        actions: <Widget>[
                                                          TextButton(
                                                            child: const Text('Cancel'),
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                            },
                                                          ),
                                                          TextButton(
                                                            child: Text(
                                                              'Delete',
                                                              style: TextStyle(color: colorScheme.error),
                                                            ),
                                                            onPressed: () {
                                                              Navigator.of(context).pop();
                                                              deleteDocument(document, model);
                                                            },
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                              Icon(
                                                Icons.chevron_right,
                                                color: colorScheme.primary,
                                                size: isSmallScreen ? 24 : 28,
                                              ),
                                            ],
                                          ),
                                          onTap: () async {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => AudioPlayerScreen(
                                                  category: category,
                                                  documentID: document.reference.parent.parent!.id,
                                                  dialogue: document.get('dialogue'),
                                                  targetLanguage: document.get('target_language'),
                                                  nativeLanguage: (document.data() as Map<String, dynamic>?)?.containsKey('native_language') == true ? document.get('native_language') : 'English (US)',
                                                  languageLevel: document.get('language_level'),
                                                  userID: FirebaseAuth.instance.currentUser!.uid,
                                                  title: document.get('title'),
                                                  generating: false,
                                                  wordsToRepeat: document.get('words_to_repeat'),
                                                  scriptDocumentId: document.id,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ))
                                  .toList(),
                          ],
                        );
                      },
                    ),
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomMenuBar(
        currentRoute: '/library',
      ),
    );
  }
}
