import 'question_model.dart';  // Modeli tanıması için şart

final List<Question> sampleQuestions = [
  // 1. SORU
  Question(
    text: "Aşağıdakilerden hangisi minenin organik yapısında en fazla bulunan proteindir?",
    options: ["A) Amelogenin", "B) Enamelin", "C) Ameloblastin", "D) Tuftelin", "E) Keratin"],
    correctIndex: 0, // A Şıkkı
    explanation: "Minenin organik matriksinin %90'ını Amelogenin oluşturur.",
  ),
  // 2. SORU 
  Question(
    text: "Lokal anesteziklerin etki mekanizması aşağıdakilerden hangisidir?",
    options: [
      "A) Potasyum kanallarını açmak",
      "B) Sodyum kanallarını bloke etmek",
      "C) Kalsiyum girişini artırmak",
      "D) Klor kanallarını kapatmak",
      "E) Asetilkolin salınımını artırmak"
    ],
    correctIndex: 1, // B Şıkkı
    explanation: "Lokal anestezikler, sinir zarındaki voltaj kapılı sodyum (Na+) kanallarını bloke ederek depolarizasyonu engeller.",
  ),
];