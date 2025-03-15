import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:parakeet/Navigation/bottom_menu_bar.dart';
import 'package:parakeet/services/home_screen_model.dart';
import 'package:parakeet/services/library_service.dart';
import 'package:parakeet/utils/constants.dart';
import 'package:parakeet/widgets/library_screen/category_section.dart';
import 'package:parakeet/widgets/library_screen/empty_view.dart';
import 'package:parakeet/widgets/profile_popup_menu.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> with WidgetsBindingObserver {
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
    final model = Provider.of<HomeScreenModel>(context, listen: false);
    final result = await LibraryService.loadDocuments(model);

    setState(() {
      documents = result['documents'];
      localFavorites = result['favorites'];
      categorizedDocuments = result['categorizedDocuments'];
      expandedCategories = result['expandedCategories'];
      isLoading = false;
    });
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

  void _handleDeleteDocument(DocumentSnapshot document) async {
    final model = Provider.of<HomeScreenModel>(context, listen: false);
    await LibraryService.deleteDocument(document, model, documents, categorizedDocuments, expandedCategories, (updatedDocuments, updatedCategorizedDocuments, updatedExpandedCategories) {
      setState(() {
        documents = updatedDocuments;
        categorizedDocuments = updatedCategorizedDocuments;
        expandedCategories = updatedExpandedCategories;
      });
    });
  }

  void _updateFavoritesState(Map<String, bool> updatedFavorites) {
    setState(() {
      localFavorites = updatedFavorites;
    });
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
      body: Consumer<HomeScreenModel>(
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
                ? EmptyLibraryView(isSmallScreen: isSmallScreen)
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 8),
                    itemCount: categorizedDocuments.length,
                    itemBuilder: (context, index) {
                      final category = categorizedDocuments.keys.elementAt(index);
                      final categoryDocs = categorizedDocuments[category]!;
                      final isExpanded = expandedCategories[category] ?? true;

                      return Padding(
                        padding: EdgeInsets.only(
                          top: index > 0 ? (isSmallScreen ? 16 : 24) : 0,
                        ),
                        child: CategorySection(
                          category: category,
                          documents: categoryDocs,
                          isExpanded: isExpanded,
                          isSmallScreen: isSmallScreen,
                          onToggleExpansion: toggleCategoryExpansion,
                          model: model,
                          localFavorites: localFavorites,
                          updateFavorites: _updateFavoritesState,
                          onDeleteDocument: _handleDeleteDocument,
                        ),
                      );
                    },
                  ),
          );
        },
      ),
      bottomNavigationBar: const BottomMenuBar(
        currentRoute: '/library',
      ),
    );
  }
}
