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

  final isAlreadyMastered = matching.isNotEmpty && (matching['scheduledDays'] == -1 || matching['scheduledDays'] == -1.0 || (matching['scheduledDays'] is num && (matching['scheduledDays'] as num) >= 100));

  final title = isAlreadyMastered ? 'Unmark as Mastered' : 'Mark as Mastered';
  final message = isAlreadyMastered ? 'This word will return to your learning queue and you will lose all progress.' : 'This word will be marked as mastered and removed from future lessons.';
  final buttonText = isAlreadyMastered ? 'Unmark as Mastered' : 'Mark as Mastered';
  final buttonIcon = isAlreadyMastered ? Icons.undo_rounded : Icons.check_circle_rounded;
  final primaryColor = isAlreadyMastered ? Colors.amber : Colors.green;

  final colorScheme = Theme.of(context).colorScheme;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (BuildContext dialogContext) {
      bool isLoading = false;
      return StatefulBuilder(builder: (BuildContext context, StateSetter setDialogState) {
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                const SizedBox(height: 24),

                const SizedBox(height: 4),

                // Word being acted upon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    word,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Message
                isLoading
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: primaryColor,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Processing...',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        message,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),

                const SizedBox(height: 32),

                // Action buttons
                if (!isLoading) ...[
                  Row(
                    children: [
                      // Cancel button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.onSurfaceVariant,
                            side: BorderSide(
                              color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Confirm button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
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
                                  'lastReview': DateTime.now().toIso8601String(),
                                  'due': DateTime.now().add(const Duration(days: 365)).toIso8601String(), // Set due date far in the future for mastered words
                                });
                              } else {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Word not found in learning records'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colorScheme.errorContainer,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
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
                                    content: Row(
                                      children: [
                                        Icon(
                                          isAlreadyMastered ? Icons.undo_rounded : Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isAlreadyMastered ? 'Word returned to learning queue' : 'Word marked as mastered!',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: primaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              } else {
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text(
                                          'Server update failed. Please try again later.',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    margin: const EdgeInsets.all(16),
                                  ),
                                );
                              }
                            } catch (e) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'An error occurred. Please try again.',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: colorScheme.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              print('Error in mastering word: $e');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            buttonText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      });
    },
  );
}
