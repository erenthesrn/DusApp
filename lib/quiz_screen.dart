import 'package:flutter/material.dart'; // Tasarım elementleri için
import 'questions.dart';                // Veri listesi için

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Artık sampleQuestions'ı diğer dosyadan otomatik tanıyacak
  final question = sampleQuestions[0]; 
  int? selectedIndex;
  bool isAnswered = false;

  void handleAnswer(int index) {
    if (isAnswered) return;
    setState(() {
      selectedIndex = index;
      isAnswered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ... Burası senin az önce çalışan kodunun aynısı ...
    // (Kodun geri kalanını buraya yapıştırdığını varsayıyorum)
    // Eğer kopyalamada sorun yaşarsan söyle, uzun halini atarım.
    return Scaffold(
      appBar: AppBar(title: const Text("Klinik Bilimler", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24), margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Text(question.text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.5, color: Color(0xFF2C3E50))),
            ),
            ...List.generate(question.options.length, (index) {
              Color bgColor = Colors.white; Color borderColor = Colors.grey.shade300; Color textColor = Colors.black87;
              if (isAnswered) {
                if (index == question.correctIndex) { bgColor = const Color(0xFFD1E7DD); borderColor = const Color(0xFF198754); textColor = const Color(0xFF0F5132); }
                else if (index == selectedIndex && index != question.correctIndex) { bgColor = const Color(0xFFF8D7DA); borderColor = const Color(0xFFDC3545); textColor = const Color(0xFF842029); }
              }
              return GestureDetector(
                onTap: () => handleAnswer(index),
                child: Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), decoration: BoxDecoration(color: bgColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)), child: Text(question.options[index], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textColor))),
              );
            }),
            if (isAnswered) Container(margin: const EdgeInsets.only(top: 20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFE7F1FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF0D6EFD).withOpacity(0.3))), child: Row(children: [const Icon(Icons.info_outline, color: Color(0xFF0D6EFD)), const SizedBox(width: 10), Expanded(child: Text(question.explanation, style: const TextStyle(color: Color(0xFF003366))))])),
          ],
        ),
      ),
    );
  }
}