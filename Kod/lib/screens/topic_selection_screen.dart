import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 224, 247, 250),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: const Color.fromARGB(255, 224, 247, 250),
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), 
              side: BorderSide(color: Colors.grey.withOpacity(0.2))
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: themeColor.withOpacity(0.1),
                child: Icon(Icons.book, color: themeColor),
              ),
              title: Text(topics[index], style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${topics[index]} seçildi.")));
              },
            ),
          );
        },
      ),
    );
  }
}