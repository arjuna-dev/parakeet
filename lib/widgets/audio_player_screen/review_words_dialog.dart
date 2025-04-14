import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:parakeet/utils/spaced_repetition_fsrs.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewWordsDialog extends StatefulWidget {
  final Map<String, dynamic> words;

  const ReviewWordsDialog({
    Key? key,
    required this.words,
  }) : super(key: key);

  @override
  State<ReviewWordsDialog> createState() => _ReviewWordsDialogState();
}

class _ReviewWordsDialogState extends State<ReviewWordsDialog> {
  int _currentWordIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Semi-transparent background
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.black54,
              ),
            ),
          ),
          // Dialog content
          Center(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 24,
                vertical: isSmallScreen ? 24 : 32,
              ),
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: screenSize.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _currentWordIndex >= widget.words.keys.toList().length ? _buildCompletionView(colorScheme, isSmallScreen) : _buildReviewView(colorScheme, isSmallScreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(ColorScheme colorScheme, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmallScreen ? 64 : 80,
            height: isSmallScreen ? 64 : 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              size: isSmallScreen ? 40 : 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Review Complete!',
            style: TextStyle(
              fontSize: isSmallScreen ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Great job reviewing your words!',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 24 : 32,
                vertical: isSmallScreen ? 12 : 16,
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewView(ColorScheme colorScheme, bool isSmallScreen) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Review Word ${_currentWordIndex + 1}/${widget.words.keys.toList().length}',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              widget.words.keys.toList()[_currentWordIndex],
              style: TextStyle(
                fontSize: isSmallScreen ? 24 : 32,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ReviewButton(
                label: 'Again',
                icon: Icons.refresh,
                color: colorScheme.error,
                onPressed: () => _handleReview(fsrs.Rating.again),
              ),
              _ReviewButton(
                label: 'Good',
                icon: Icons.check,
                color: colorScheme.primary,
                onPressed: () => _handleReview(fsrs.Rating.good),
              ),
              _ReviewButton(
                label: 'Easy',
                icon: Icons.star,
                color: colorScheme.tertiary,
                onPressed: () => _handleReview(fsrs.Rating.easy),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _handleReview(fsrs.Rating rating) async {
    final word = widget.words.keys.toList()[_currentWordIndex];

    // Get the word document from the correct path
    final docRef = widget.words[word];

    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final wordCard = WordCard.fromFirestore(data);

      // Create FSRS instance and get new scheduling
      final f = fsrs.FSRS();
      final now = DateTime.now();
      final scheduling = f.repeat(wordCard.card, now);
      final newCard = scheduling[rating]!.card;

      // Create new WordCard with updated card
      final updatedWordCard = WordCard(
        word: word,
        due: newCard.due,
        lastReview: now,
        stability: newCard.stability,
        difficulty: newCard.difficulty,
        elapsedDays: newCard.elapsedDays,
        scheduledDays: newCard.scheduledDays,
        reps: newCard.reps,
        lapses: newCard.lapses,
        state: newCard.state,
      );

      // Save the updated card
      await docRef.set(updatedWordCard.toFirestore(), SetOptions(merge: true));
    }

    // Move to next word
    setState(() {
      _currentWordIndex++;
    });
  }
}

class _ReviewButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ReviewButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.height < 700;

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 8 : 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: Icon(icon, size: isSmallScreen ? 20 : 24),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
