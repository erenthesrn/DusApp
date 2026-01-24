import 'package:flutter/material.dart';
import 'quiz_screen.dart';

void main() {
  runApp(const DusApp());
}

class DusApp extends StatelessWidget {
  const DusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DUS APP',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: const Color(0xFF007AFF),
        fontFamily: 'Roboto',
      ),
      home: const QuizScreen(), //Başlangıçta quizscreen ekranını aç.
    );
  }
}
