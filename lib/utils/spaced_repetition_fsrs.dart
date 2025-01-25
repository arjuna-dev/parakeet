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

  static WordCard fromFirestore(Map<String, dynamic> data) {
    return WordCard(
      word: data['word'] as String,
      due: DateTime.parse(data['due'] as String),
      lastReview: DateTime.parse(data['lastReview'] as String),
      stability: (data['stability'] ?? 0).toDouble(),
      difficulty: (data['difficulty'] ?? 0).toDouble(),
      elapsedDays: data['elapsedDays'] ?? 0,
      scheduledDays: data['scheduledDays'] ?? 0,
      reps: data['reps'] ?? 0,
      lapses: data['lapses'] ?? 0,
      state: fsrs.State.values[data['state'] ?? 0],
    );
  }
}
