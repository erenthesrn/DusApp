// lib/models/question_model.dart
class Question {
  final int id;
  final String question;
  final List<String> options;
  final int answerIndex;

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
  });

  // JSON'dan Nesneye Çeviren Fabrika
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      answerIndex: json['answer_index'],
    );
  }
}