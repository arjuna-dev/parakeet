import 'package:fsrs/fsrs.dart' as fsrs;

class WordCard {
  final String word;
  final fsrs.Card card;

  WordCard({
    required this.word,
    required DateTime due,
    required DateTime lastReview,
    double stability = 0,
    double difficulty = 0,
    int elapsedDays = 0,
    int scheduledDays = 0,
    int reps = 0,
    int lapses = 0,
    fsrs.State state = fsrs.State.newState,
  }) : card = fsrs.Card.def(
          due,
          lastReview,
          stability,
          difficulty,
          elapsedDays,
          scheduledDays,
          reps,
          lapses,
          state,
        );

  Map<String, dynamic> toFirestore() {
    return {
      'word': word,
      'due': card.due.toIso8601String(),
      'lastReview': card.lastReview.toIso8601String(),
      'stability': card.stability,
      'difficulty': card.difficulty,
      'elapsedDays': card.elapsedDays,
      'scheduledDays': card.scheduledDays,
      'reps': card.reps,
      'lapses': card.lapses,
      'state': card.state.index,
    };
  }

  static WordCard fromFirestore(Map<String, dynamic> cardData) {
    print("in fromFirestore, cardData: $cardData");
    // Defensive conversion for int/double fields
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    final dueRaw = cardData['due'];
    final lastReviewRaw = cardData['lastReview'];
    final due = dueRaw is String ? DateTime.parse(dueRaw) : (dueRaw is DateTime ? dueRaw : DateTime.now());
    final lastReview = lastReviewRaw is String ? DateTime.parse(lastReviewRaw) : (lastReviewRaw is DateTime ? lastReviewRaw : DateTime.now());
    final card = fsrs.Card.def(
      due,
      lastReview,
      parseDouble(cardData['stability'] ?? 0),
      parseDouble(cardData['difficulty'] ?? 0),
      parseInt(cardData['elapsedDays'] ?? 0),
      parseInt(cardData['scheduledDays'] ?? 0),
      parseInt(cardData['reps'] ?? 0),
      parseInt(cardData['lapses'] ?? 0),
      fsrs.State.values[cardData['state'] is int ? cardData['state'] : int.tryParse(cardData['state']?.toString() ?? '0') ?? 0],
    );
    return WordCard(
      word: cardData['word'] as String,
      due: card.due,
      lastReview: card.lastReview,
      stability: card.stability,
      difficulty: card.difficulty,
      elapsedDays: card.elapsedDays,
      scheduledDays: card.scheduledDays,
      reps: card.reps,
      lapses: card.lapses,
      state: card.state,
    );
  }
}
