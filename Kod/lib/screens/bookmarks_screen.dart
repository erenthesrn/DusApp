import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bookmark_service.dart';
import '../models/question_model.dart';
import 'quiz_screen.dart'; // Soruyu açmak için

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF5F9FF);
    final Color cardColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Kaydedilen Sorular", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: BookmarkService.getBookmarksStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text("Henüz soru kaydetmedin.", style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              
              // Modeli oluştur
              Question question = Question(
                id: data['id'] ?? 0,
                question: data['question'] ?? "",
                options: List<String>.from(data['options'] ?? []),
                answerIndex: data['correctIndex'] ?? 0,
                level: data['topic'] ?? "Genel",
                testNo: data['testNo'] ?? 1,
                explanation: data['explanation'] ?? "",
                imageUrl: data['image_url'],
              );

              return Dismissible(
                key: Key(docs[index].id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) async {
                  // Listeden kaydırarak silme özelliği
                  await BookmarkService.toggleBookmark(question, data['topic']);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.bookmark, color: Colors.orange),
                    ),
                    title: Text(
                      question.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text(data['topic'] ?? "Genel", style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    onTap: () {
                      // Soruyu çözmek için Quiz ekranını "İnceleme Modu"nda açıyoruz
                      // Ama sadece bu soruyu içeren bir liste gönderiyoruz
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuizScreen(
                            isTrial: true,
                            isReviewMode: false, // Kullanıcı tekrar çözebilsin diye false
                            questions: [question], // Sadece bu soru
                            topic: data['topic'],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}