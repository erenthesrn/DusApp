class Question {
  final int id;
  final String question;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String level;
  final int testNo;
  final String? imageUrl;


  Question({
    required this.id,
    required this.question,
    required this.options,
    required this.answerIndex,
    required this.level,
    required this.testNo,
    this.explanation = "",
    this.imageUrl,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    // 🛠️ DÜZELTME: ID TİP KONTROLÜ
    // Firestore'dan gelen veri String ID ("Anatomi_1_14") içerebilir.
    // Question model int ID bekliyor.
    
    int parsedId = 0;
    
    if (json['id'] is int) {
      parsedId = json['id'];
    } else if (json['questionIndex'] is int) {
      // Eğer id string ise, gerçek soru numarasını 'questionIndex'ten al
      parsedId = json['questionIndex'];
    } else if (json['id'] is String) {
      // Hiçbiri yoksa ve id String ise (örn: "Anatomi_1_14"), son kısmı (14) ayıkla
      try {
        String idStr = json['id'];
        var parts = idStr.split('_');
        if (parts.isNotEmpty) {
           parsedId = int.tryParse(parts.last) ?? 0;
        }
      } catch (e) {
        parsedId = 0;
      }
    }

return Question(
      id: parsedId,
      question: json['question'] ?? "Soru yüklenemedi",
      options: json['options'] != null ? List<String>.from(json['options']) : [],
      answerIndex: json['answerIndex'] ?? json['correctIndex'] ?? json['answer_index'] ?? 0,
      explanation: json['explanation'] ?? "Açıklama bulunmuyor.",
      level: json['level'] ?? json['topic'] ?? "Kolay", 
      testNo: json['testNo'] ?? json['test_no'] ?? 1,
      imageUrl: json['image_url'], // 🔥 YENİ EKLENEN: JSON'dan 'image_url'yi çek
    );
  }
}