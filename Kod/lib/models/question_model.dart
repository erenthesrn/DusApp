// lib/models/question_model.dart
class Question {
  final int id;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  
  // 🔥 YENİ EKLENEN ALANLAR (Hatanın sebebi bunlardı)
  final String level;   // "Kolay", "Orta", "Zor"
  final int testNo;     // 1, 2, 3...

  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.level,
    required this.testNo,
    this.explanation = "",
  });

  // JSON'dan Nesneye Çeviren Fabrika
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      answerIndex: json['answer_index'],
      explanation: json['explanation'] ?? "Açıklama bulunmuyor.",
      
      // 🔥 Eğer JSON'da bu bilgiler yoksa varsayılan değer ata (Uygulama çökmesin diye)
      level: json['level'] ?? "Kolay", 
      testNo: json['test_no'] ?? 1,    
    );
  }
}