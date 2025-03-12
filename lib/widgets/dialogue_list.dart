import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DialogueList extends StatefulWidget {
  final List<dynamic> dialogue;
  final String currentTrack;
  final List<dynamic> wordsToRepeat;
  final String documentID;
  final bool useStream;

  const DialogueList({
    Key? key,
    required this.dialogue,
    required this.currentTrack,
    required this.wordsToRepeat,
    this.documentID = '',
    this.useStream = false,
  }) : super(key: key);

  @override
  _DialogueListState createState() => _DialogueListState();
}

class _DialogueListState extends State<DialogueList> {
  int _lastHighlightedIndex = -1;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<List<dynamic>> _dialogueNotifier = ValueNotifier<List<dynamic>>([]);
  Stream<QuerySnapshot>? _dialogueStream;

  @override
  void initState() {
    super.initState();
    _dialogueNotifier.value = List.from(widget.dialogue);
    if (widget.useStream && widget.documentID.isNotEmpty) {
      _dialogueStream = FirebaseFirestore.instance.collection('chatGPT_responses').doc(widget.documentID).collection('only_target_sentences').snapshots();
    }
  }

  @override
  void didUpdateWidget(covariant DialogueList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the last highlighted index only if the current track is a dialogue
    List<String> parts = widget.currentTrack.split('_');
    if (parts.length >= 2 && parts[0] == 'dialogue') {
      int currentDialogueIndex = int.tryParse(parts[1]) ?? -1;
      if (currentDialogueIndex >= 0) {
        _lastHighlightedIndex = currentDialogueIndex;

        // Auto-scroll to the highlighted item if it's beyond the visible area
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && currentDialogueIndex > 0) {
            const itemHeight = 120.0; // Approximate height of each dialogue item
            final targetPosition = itemHeight * currentDialogueIndex;

            if (targetPosition > _scrollController.position.pixels + _scrollController.position.viewportDimension || targetPosition < _scrollController.position.pixels) {
              _scrollController.animateTo(
                targetPosition,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        });
      }
    }

    // Update dialogue only if it actually changed
    if (!_areDialoguesEqual(widget.dialogue, _dialogueNotifier.value)) {
      _dialogueNotifier.value = List.from(widget.dialogue);
    }
  }

  // Helper method to check if two dialogue lists are equal
  bool _areDialoguesEqual(List<dynamic> list1, List<dynamic> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i]['target_language'] != list2[i]['target_language'] || list1[i]['native_language'] != list2[i]['native_language']) {
        return false;
      }
    }
    return true;
  }

  Widget _buildDialogueItem(BuildContext context, dynamic dialogueItem, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    String dialogueTarget = dialogueItem["target_language"] ?? "";
    String dialogueNative = dialogueItem["native_language"] ?? "";

    // Check if this dialogue should be highlighted based on the last known dialogue index
    bool shouldHighlight = index == _lastHighlightedIndex;
    bool isEven = index.isEven;

    return RepaintBoundary(
      child: Container(
        key: ValueKey('dialogue_$index'),
        width: MediaQuery.of(context).size.width * 0.8,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEven ? const Color.fromARGB(255, 85, 52, 115) : const Color.fromARGB(255, 62, 59, 124),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: shouldHighlight ? colorScheme.onPrimaryContainer.withOpacity(0.5) : colorScheme.shadow.withOpacity(0.6),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(-3, 3),
            ),
          ],
        ),
        child: ListTile(
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogueNative, style: TextStyle(color: colorScheme.primary, fontWeight: shouldHighlight ? FontWeight.bold : FontWeight.normal)),
              Wrap(
                children: dialogueTarget.split(' ').map<Widget>((word) {
                  final cleanWord = word.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').toLowerCase();
                  final match = widget.wordsToRepeat.contains(cleanWord);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0.0),
                    margin: EdgeInsets.zero,
                    child: Text(
                      word,
                      style: TextStyle(
                        fontSize: 17,
                        color: match ? colorScheme.tertiary : colorScheme.tertiaryFixed,
                        fontWeight: shouldHighlight || match ? FontWeight.bold : FontWeight.normal,
                        decoration: match ? TextDecoration.underline : TextDecoration.none,
                        decorationThickness: match ? 1.0 : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If streaming is enabled and we have a document ID, use StreamBuilder
    if (widget.useStream && widget.documentID.isNotEmpty && _dialogueStream != null) {
      return Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _dialogueStream,
          builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong'));
            }

            if (snapshot.connectionState == ConnectionState.waiting && _dialogueNotifier.value.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // Update dialogue data if new data is available
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final Map<String, dynamic> data = snapshot.data!.docs[0].data() as Map<String, dynamic>;
              if (data.containsKey('dialogue')) {
                final newDialogueData = data['dialogue'] as List<dynamic>;
                if (!_areDialoguesEqual(newDialogueData, _dialogueNotifier.value)) {
                  _dialogueNotifier.value = List.from(newDialogueData);
                }
              }
            }

            return ValueListenableBuilder<List<dynamic>>(
              valueListenable: _dialogueNotifier,
              builder: (context, dialogueData, child) {
                return ListView.builder(
                  key: const PageStorageKey('dialogue_list'),
                  controller: _scrollController,
                  itemCount: dialogueData.length,
                  itemBuilder: (context, index) {
                    if (index >= dialogueData.length) {
                      return Container();
                    }
                    return _buildDialogueItem(context, dialogueData[index], index);
                  },
                );
              },
            );
          },
        ),
      );
    } else {
      // Use the existing dialogue list if streaming is not enabled
      return Expanded(
        child: ValueListenableBuilder<List<dynamic>>(
          valueListenable: _dialogueNotifier,
          builder: (context, dialogueData, child) {
            return ListView.builder(
              key: const PageStorageKey('dialogue_list'),
              controller: _scrollController,
              itemCount: dialogueData.length,
              itemBuilder: (context, index) {
                return _buildDialogueItem(context, dialogueData[index], index);
              },
            );
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dialogueNotifier.dispose();
    super.dispose();
  }
}
