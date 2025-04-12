import 'package:flutter/material.dart';

class WordSelectionDialog extends StatefulWidget {
  final List<String> allWords;
  final List<String> selectedWords;
  final int maxWordsAllowed;
  final Function(List<String>) onSave;

  const WordSelectionDialog({
    Key? key,
    required this.allWords,
    required this.selectedWords,
    required this.maxWordsAllowed,
    required this.onSave,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required List<String> allWords,
    required List<String> selectedWords,
    required int maxWordsAllowed,
    required Function(List<String>) onSave,
  }) async {
    // Get screen size for responsive dialog
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width > 600 ? 500.0 : screenSize.width * 0.9;
    final dialogHeight = screenSize.height * 0.6;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: (screenSize.width - dialogWidth) / 2,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: dialogHeight),
            child: WordSelectionDialog(
              allWords: allWords,
              selectedWords: selectedWords,
              maxWordsAllowed: maxWordsAllowed,
              onSave: onSave,
            ),
          ),
        );
      },
    );
  }

  @override
  State<WordSelectionDialog> createState() => _WordSelectionDialogState();
}

class _WordSelectionDialogState extends State<WordSelectionDialog> {
  late List<String> _tempSelectedWords;

  @override
  void initState() {
    super.initState();
    _tempSelectedWords = List<String>.from(widget.selectedWords);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Select Words to Learn (${_tempSelectedWords.length}/${widget.maxWordsAllowed})',
            style: TextStyle(
              fontSize: isSmallScreen ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (_tempSelectedWords.length >= widget.maxWordsAllowed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Maximum ${widget.maxWordsAllowed} words allowed. Unselect a word to select another.',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        const Divider(),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.allWords.length,
            itemBuilder: (context, index) {
              final word = widget.allWords[index].toLowerCase();
              final isSelected = _tempSelectedWords.map((w) => w.toLowerCase()).contains(word);

              return CheckboxListTile(
                title: Text(
                  word,
                  style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
                ),
                value: isSelected,
                onChanged: (_tempSelectedWords.length >= widget.maxWordsAllowed && !isSelected)
                    ? null // Disable checkbox if max words reached and this word is not selected
                    : (bool? value) {
                        setState(() {
                          if (value == true) {
                            _tempSelectedWords.add(word);
                          } else {
                            _tempSelectedWords.removeWhere((w) => w.toLowerCase() == word.toLowerCase());
                          }
                        });
                      },
                activeColor: colorScheme.primary,
                dense: true,
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _tempSelectedWords.isEmpty
                    ? null // Disable save button if no words selected
                    : () {
                        // Ensure all words are lowercase when saving
                        widget.onSave(_tempSelectedWords.map((w) => w.toLowerCase()).toList());
                        Navigator.of(context).pop();
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
