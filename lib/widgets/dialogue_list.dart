import 'package:flutter/material.dart';

class DialogueList extends StatefulWidget {
  final List<dynamic> dialogue;
  final String currentTrack;
  final List<dynamic> wordsToRepeat;

  const DialogueList({
    Key? key,
    required this.dialogue,
    required this.currentTrack,
    required this.wordsToRepeat,
  }) : super(key: key);

  @override
  _DialogueListState createState() => _DialogueListState();
}

class _DialogueListState extends State<DialogueList> {
  int _lastHighlightedIndex = -1;

  @override
  void didUpdateWidget(covariant DialogueList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update the last highlighted index only if the current track is a dialogue
    List<String> parts = widget.currentTrack.split('_');
    if (parts.length >= 2 && parts[0] == 'dialogue') {
      int currentDialogueIndex = int.tryParse(parts[1]) ?? -1;
      if (currentDialogueIndex >= 0) {
        _lastHighlightedIndex = currentDialogueIndex;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: widget.dialogue.length,
        itemBuilder: (context, index) {
          String dialogueTarget = widget.dialogue[index]["target_language"];
          String dialogueNative = widget.dialogue[index]["native_language"];

          // Check if this dialogue should be highlighted based on the last known dialogue index
          bool shouldHighlight = index == _lastHighlightedIndex;

          return Column(
            children: [
              ListTile(
                title: Text(
                  "Dialogue ${index + 1}:",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dialogueNative,
                      style: TextStyle(
                        fontWeight: shouldHighlight
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: shouldHighlight ? Colors.blue : Colors.black,
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        children: dialogueTarget.split(' ').map((word) {
                          final cleanWord = word
                              .replaceAll(
                                  RegExp(r'[^\p{L}\s]', unicode: true), '')
                              .toLowerCase();
                          final match =
                              widget.wordsToRepeat.contains(cleanWord);
                          return TextSpan(
                            text: '$word ',
                            style: TextStyle(
                              fontSize: 16,
                              color: match
                                  ? Colors.green
                                  : (shouldHighlight
                                      ? Colors.purple
                                      : Colors.black),
                              fontWeight: shouldHighlight
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              decoration: match
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: match
                                  ? const Color.fromARGB(255, 21, 87, 25)
                                  : null,
                              decorationThickness: match ? 2.0 : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
