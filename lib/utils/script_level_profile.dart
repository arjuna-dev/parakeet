/// Normalized learner tier from user profile strings (Firestore may store
/// "Absolute beginner (A1)", "Beginner", onboarding values without CEFR, etc.).
enum LanguageLearnerTier {
  absoluteBeginner,
  beginner,
  intermediate,
  advanced,
}

/// Maps profile/onboarding [languageLevel] strings to [LanguageLearnerTier].
LanguageLearnerTier parseLanguageLearnerTier(String languageLevel) {
  final s = languageLevel.trim().toLowerCase();
  if (s.isEmpty) {
    return LanguageLearnerTier.intermediate;
  }
  if (s.contains('absolute') || _cefrRank(s) == 1) {
    return LanguageLearnerTier.absoluteBeginner;
  }
  if (s.contains('beginner') || _cefrRank(s) == 2) {
    return LanguageLearnerTier.beginner;
  }
  if (s.contains('intermediate') || _cefrRank(s) == 3 || _cefrRank(s) == 4) {
    return LanguageLearnerTier.intermediate;
  }
  if (s.contains('advanced') || _cefrRank(s) >= 5) {
    return LanguageLearnerTier.advanced;
  }
  return LanguageLearnerTier.intermediate;
}

/// Returns 1–6 for A1–C2 if present in the string, else 0.
int _cefrRank(String s) {
  if (RegExp(r'\ba1\b').hasMatch(s)) return 1;
  if (RegExp(r'\ba2\b').hasMatch(s)) return 2;
  if (RegExp(r'\bb1\b').hasMatch(s)) return 3;
  if (RegExp(r'\bb2\b').hasMatch(s)) return 4;
  if (RegExp(r'\bc1\b').hasMatch(s)) return 5;
  if (RegExp(r'\bc2\b').hasMatch(s)) return 6;
  return 0;
}
