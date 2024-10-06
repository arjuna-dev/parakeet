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
  // ignore: library_private_types_in_public_api
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
          bool isEven = index.isEven;

          return Column(
            children: [
              Align(
                alignment: isEven ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8, // Occupies 80% of the parent container width
                  margin: const EdgeInsets.symmetric(vertical: 8), // Adds vertical spacing between messages
                  padding: const EdgeInsets.all(12), // Adds padding inside the box
                  decoration: BoxDecoration(
                    color: isEven ? Colors.purple[50] : Colors.deepPurple[100], // Different background colors for even/odd
                    borderRadius: BorderRadius.circular(15), // Rounded corners for the message box
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2), // Adds a shadow effect
                      ),
                    ],
                  ),
                  child: ListTile(
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dialogueNative),
                        RichText(
                          text: TextSpan(
                            children: dialogueTarget.split(' ').map((word) {
                              final cleanWord = word.replaceAll(RegExp(r'[^\p{L}\s]', unicode: true), '').toLowerCase();
                              final match = widget.wordsToRepeat.contains(cleanWord);
                              return TextSpan(
                                text: '$word ',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: match ? Colors.purple : (shouldHighlight ? Colors.purple : Colors.black),
                                  fontWeight: shouldHighlight || match ? FontWeight.bold : FontWeight.normal,
                                  decoration: match ? TextDecoration.underline : TextDecoration.none,
                                  decorationThickness: match ? 1.0 : null,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
