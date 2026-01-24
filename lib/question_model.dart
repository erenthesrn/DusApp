// --- VERİ MODELİ (SORU KALIBI) ---
class Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}
