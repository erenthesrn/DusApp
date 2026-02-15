import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/bookmark_service.dart';
import '../models/question_model.dart';

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
        title: Text("Kaydedilen Sorular",
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
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
                  Text("Henüz soru kaydetmedin.",
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
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

              // 🔥 FIX: Her iki field'ı da kontrol et
              String? imageUrl = data['image_url'] ?? data['imageUrl'];

              // Modeli oluştur
              Question question = Question(
                id: data['id'] ?? 0,
                question: data['question'] ?? "",
                options: List<String>.from(data['options'] ?? []),
                answerIndex: data['correctIndex'] ?? 0,
                level: data['topic'] ?? "Genel",
                testNo: data['testNo'] ?? 1,
                explanation: data['explanation'] ?? "",
                imageUrl: imageUrl, // 🔥 FIX: Düzeltilmiş alan
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
                  await BookmarkService.toggleBookmark(question, data['topic']);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
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
                            decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(data['topic'] ?? "Genel",
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookmarkDetailScreen(
                            question: question,
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

// ==========================================
// YENİ EKRAN: KAYDEDİLEN SORU DETAYI (GÖRSEL DESTEKLİ - FİX)
// ==========================================

class BookmarkDetailScreen extends StatefulWidget {
  final Question question;
  final String? topic;

  const BookmarkDetailScreen({super.key, required this.question, this.topic});

  @override
  State<BookmarkDetailScreen> createState() => _BookmarkDetailScreenState();
}

class _BookmarkDetailScreenState extends State<BookmarkDetailScreen> {
  bool _showAnswer = false;
  bool _isBookmarked = true;

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length == 1) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey.shade600;

    String topicText = widget.topic ?? widget.question.level;
    topicText = _toTitleCase(topicText);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Soru İncele",
            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),

        actions: [
          IconButton(
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.orange : textColor,
              size: 28,
            ),
            onPressed: () async {
              // 1. Durumu güncelle (ikon hemen değişsin)
              setState(() {
                _isBookmarked = !_isBookmarked;
              });

              // 2. Servisi çağır
              await BookmarkService.toggleBookmark(widget.question, widget.topic ?? "Genel");

              // 3. Kullanıcıya bilgi ver
              if (mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isBookmarked 
                        ? "Soru tekrar kaydedildi" 
                        : "Kaydedilenlerden çıkarıldı",
                      style: GoogleFonts.inter(),
                    ),
                    backgroundColor: _isBookmarked ? Colors.green : Colors.redAccent,
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8), // Sağdan biraz boşluk
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
            border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Konu ve Test Başlığı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: isDark
                              ? Colors.blueAccent.withOpacity(0.1)
                              : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3))),
                      child: Text("$topicText • Test ${widget.question.testNo}",
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Soru Metni
                Text(widget.question.question,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: textColor)),

                // --- GÖRSEL ALANI (DÜZELTİLMİŞ) ---
                if (widget.question.imageUrl != null && widget.question.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        widget.question.imageUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: Colors.teal,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Görsel yükleniyor...",
                                    style: TextStyle(
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          // 🔥 DEBUG: Hatayı göster
                          debugPrint("❌ Görsel yükleme hatası: $error");
                          debugPrint("📷 URL: ${widget.question.imageUrl}");
                          
                          return Container(
                            height: 150,
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded, 
                                     color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, 
                                     size: 40),
                                const SizedBox(height: 8),
                                Text("Görsel yüklenemedi", 
                                     style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600)),
                                const SizedBox(height: 4),
                                // 🔥 DEBUG bilgisi
                                Text(
                                  "URL: ${widget.question.imageUrl!.substring(0, widget.question.imageUrl!.length > 30 ? 30 : widget.question.imageUrl!.length)}...",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                // ---------------------------

                const SizedBox(height: 16),

                // Şıklar
                if (widget.question.options.isNotEmpty)
                  ...List.generate(widget.question.options.length, (i) {
                    bool isCorrect = (i == widget.question.answerIndex);
                    
                    Color rowBg = Colors.transparent;
                    Color rowBorder = isDark ? Colors.white10 : Colors.grey.shade200;
                    IconData? icon;
                    Color iconColor = subTextColor;
                    Color textOptionColor = subTextColor;

                    if (_showAnswer && isCorrect) {
                      rowBg = isDark
                          ? Colors.green.withOpacity(0.15)
                          : const Color(0xFFF0FDF4);
                      rowBorder = Colors.green.withOpacity(0.4);
                      icon = Icons.check_circle;
                      iconColor = Colors.green;
                      textOptionColor = isDark ? Colors.white : Colors.black87;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: rowBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: rowBorder)),
                      child: Row(
                        children: [
                          Text(String.fromCharCode(65 + i),
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: (_showAnswer && isCorrect)
                                      ? iconColor
                                      : subTextColor)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(widget.question.options[i],
                                  style: GoogleFonts.inter(
                                      color: (_showAnswer && isCorrect)
                                          ? textOptionColor
                                          : (isDark ? Colors.white70 : Colors.black87),
                                      fontWeight: (_showAnswer && isCorrect)
                                          ? FontWeight.w600
                                          : FontWeight.normal))),
                          if (icon != null) Icon(icon, size: 18, color: iconColor)
                        ],
                      ),
                    );
                  })
                else
                  const Text("⚠️ Şık verisi bulunamadı.",
                      style: TextStyle(color: Colors.red, fontSize: 12)),

                const SizedBox(height: 20),

                // Cevabı Göster Butonu
                if (!_showAnswer)
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showAnswer = true;
                        });
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text("Doğru Cevabı Göster"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.teal.shade800 : Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        )
                      ),
                    ),
                  ),

                // Açıklama Alanı
                if (_showAnswer && widget.question.explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueGrey.withOpacity(0.1)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: subTextColor),
                            const SizedBox(width: 8),
                            Text("Açıklama",
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: subTextColor)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(widget.question.explanation,
                            style: GoogleFonts.inter(
                                color: textColor.withOpacity(0.8),
                                fontSize: 13,
                                height: 1.4,
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
