// lib/screens/topic_selection_screen.dart

import 'package:flutter/material.dart';
import 'test_list_screen.dart';

class TopicSelectionScreen extends StatelessWidget {
  final String title;
  final List<String> topics;
  final Color themeColor; 

  const TopicSelectionScreen({
    super.key, 
    required this.title, 
    required this.topics,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Tema Kontrolü
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Renk Tanımları
    // Arkaplan: Koyu modda Siyah, Açık modda senin orijinal açık mavisi
    Color scaffoldBackgroundColor = isDarkMode ? Colors.black : const Color.fromARGB(255, 224, 247, 250);
    
    // AppBar Başlık Rengi: Koyu modda Beyaz, Açık modda Siyah
    Color appBarTitleColor = isDarkMode ? Colors.white : Colors.black;

    // Kart Rengi: Koyu modda göz yormayan Koyu Gri, Açık modda Beyaz
    Color cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;

    // Kart İçi Yazı Rengi: Kart koyuysa yazı beyaz, kart beyazsa yazı siyah
    Color cardTextColor = isDarkMode ? Colors.white : Colors.black87;

    // Kart Kenarlığı: Koyu modda kartın sınırları belli olsun diye hafif çizgi
    Color borderColor = isDarkMode ? Colors.white12 : Colors.grey.withOpacity(0.2);

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor, 
      appBar: AppBar(
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: appBarTitleColor 
          )
        ),
        backgroundColor: scaffoldBackgroundColor, 
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: topics.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return Card(
            elevation: 0,
            color: cardColor, // Dinamik kart rengi
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: borderColor) // Dinamik kenarlık
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: themeColor.withOpacity(0.1),
                child: Icon(Icons.book, color: themeColor),
              ),
              title: Text(
                topics[index], 
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cardTextColor // Dinamik yazı rengi
                )
              ),
              trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDarkMode ? Colors.grey : Colors.grey.shade400),
              onTap: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => TestListScreen(
                    topic: topics[index], 
                    themeColor: themeColor, 
                  ))
                );              
              },
            ),
          );
        },
      ),
    );
  }
}