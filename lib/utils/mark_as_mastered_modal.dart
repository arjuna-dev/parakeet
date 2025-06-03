import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Shows a modal dialog to mark or unmark a word as mastered.
///
/// [context] - BuildContext for the dialog
/// [word] - The word to mark/unmark
/// [categoryName] - The Firestore category name
/// [targetLanguage] - The target language string
/// [learningWords] - The current list of learning words (mutable)
/// [updateLearningWords] - Callback to update the learning words list in the parent
/// [loadWordStats] - Callback to reload word stats in the parent

Future<void> showMarkAsMasteredModal({
  required BuildContext context,
  required String word,
  required String categoryName,
  required String targetLanguage,
  required List<Map<String, dynamic>> learningWords,
  required void Function(List<Map<String, dynamic>>) updateLearningWords,
  required Future<void> Function() loadWordStats,
}) async {
  print('[showMarkAsMasteredModal] learningWords type: \\${learningWords.runtimeType}');
  if (learningWords.isNotEmpty) {
    print('[showMarkAsMasteredModal] learningWords[0] type: \\${learningWords[0].runtimeType}');
  }
  final matching = learningWords.firstWhere(
    (element) => element['word'] == word.toLowerCase(),
    orElse: () {
      print('[showMarkAsMasteredModal] orElse triggered, returning <String, dynamic>{}');
      return <String, dynamic>{};
    },
  );
  print('[showMarkAsMasteredModal] matching type: \\${matching.runtimeType}');

  final isAlreadyMastered = matching.isNotEmpty && (matching['scheduledDays'] == -1 || (matching['scheduledDays'] is double && (matching['scheduledDays'] as double) == -1.0));

  final title = isAlreadyMastered ? 'Unmark as Mastered' : 'Mark as Mastered';
  final message =
      isAlreadyMastered ? 'Do you want to unmark this word as mastered? It will return to your learning queue.' : 'Do you want to mark this word as mastered? You will not learn this word anymore in the future.';
  final buttonText = isAlreadyMastered ? 'Unmark as Mastered' : 'Mark as Mastered';
  final buttonIcon = isAlreadyMastered ? Icons.undo : Icons.flag;
  final iconColor = isAlreadyMastered ? Colors.amber : Colors.green;

  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      bool isLoading = false;
      return StatefulBuilder(builder: (BuildContext context, StateSetter setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(buttonIcon, color: iconColor, size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: isLoading
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing...', style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                )
              : Text(message, style: const TextStyle(fontSize: 16)),
          actions: isLoading
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    icon: Icon(buttonIcon),
                    label: Text(buttonText),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      setDialogState(() => isLoading = true);
                      try {
                        final userId = FirebaseAuth.instance.currentUser!.uid;
                        final wordsCol = FirebaseFirestore.instance.collection('users').doc(userId).collection('${targetLanguage}_words').doc(categoryName).collection(categoryName);
                        final snap = await wordsCol.where('word', isEqualTo: word.toLowerCase()).get();
                        final newScheduledDays = isAlreadyMastered ? 0.0 : -1.0;
                        DocumentReference? ref;
                        if (snap.docs.isNotEmpty) {
                          ref = snap.docs.first.reference;
                          final doc = await ref.get();
                          if (doc.exists) {
                            final data = doc.data() as Map<String, dynamic>;
                            data['scheduledDays'] = newScheduledDays;
                            await ref.set(data, SetOptions(merge: true));
                          }
                        } else if (!isAlreadyMastered) {
                          ref = wordsCol.doc(word.toLowerCase());
                          await ref.set({
                            'word': word.toLowerCase(),
                            'scheduledDays': newScheduledDays,
                            'stability': 0.0,
                            'difficulty': 0.0,
                            'reps': 1,
                            'lapses': 0,
                            'lastReview': DateTime.now().millisecondsSinceEpoch,
                            'due': 0,
                          });
                        } else {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Word not found in learning records'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                              margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            ),
                          );
                          return;
                        }
                        // Retry mechanism: check scheduledDays value up to 10 times
                        bool confirmed = false;
                        int retries = 0;
                        while (!confirmed && retries < 10) {
                          await Future.delayed(const Duration(milliseconds: 500));
                          final checkDoc = await ref.get();
                          if (checkDoc.exists) {
                            final checkData = checkDoc.data() as Map<String, dynamic>;
                            if (checkData['scheduledDays'] == newScheduledDays) {
                              confirmed = true;
                              break;
                            }
                          }
                          retries++;
                        }
                        if (confirmed) {
                          // Update local state
                          final idx = learningWords.indexWhere((element) => element['word'] == word.toLowerCase());
                          if (idx != -1) {
                            learningWords[idx]['scheduledDays'] = newScheduledDays;
                          } else if (!isAlreadyMastered) {
                            learningWords.add({'word': word.toLowerCase(), 'scheduledDays': newScheduledDays, 'reps': 1});
                          }
                          updateLearningWords(List<Map<String, dynamic>>.from(learningWords));
                          await loadWordStats();
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isAlreadyMastered ? 'Word returned to learning queue' : 'Word marked as mastered!'),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                              ),
                            ),
                          );
                        } else {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Server update failed. Please try again later.'),
                              backgroundColor: Theme.of(context).colorScheme.errorContainer,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            ),
                          );
                        }
                      } catch (e) {
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('An error occurred. Please try again.'),
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          ),
                        );
                        print('Error in mastering word: $e');
                      }
                    },
                  ),
                ],
        );
      });
    },
  );
}
