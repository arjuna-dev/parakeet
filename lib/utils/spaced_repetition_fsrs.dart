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
    final card = fsrs.Card.def(
      DateTime.parse(cardData['due'] as String),
      DateTime.parse(cardData['lastReview'] as String),
      (cardData['stability'] ?? 0).toDouble(),
      (cardData['difficulty'] ?? 0).toDouble(),
      cardData['elapsedDays'] ?? 0,
      cardData['scheduledDays'] ?? 0,
      cardData['reps'] ?? 0,
      cardData['lapses'] ?? 0,
      fsrs.State.values[cardData['state'] ?? 0],
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
