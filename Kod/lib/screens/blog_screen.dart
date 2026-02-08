// lib/screens/blog_screen.dart

import 'dart:ui'; // Blur efekti için gerekli
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// -----------------------------------------------------------------------------
// 1. ADIM: VERİ MODELİ (AYNEN KORUNDU)
// -----------------------------------------------------------------------------
class BlogPost {
  final String id;
  final String title;
  final String category;
  final String imageUrl;
  final DateTime publishedAt;
  final String readTime;

  BlogPost({
    required this.id,
    required this.title,
    required this.category,
    required this.imageUrl,
    required this.publishedAt,
    required this.readTime,
  });

  factory BlogPost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return BlogPost(
      id: doc.id,
      title: data['title'] ?? 'Başlıksız',
      category: data['category'] ?? 'Genel',
      imageUrl: data['imageUrl'] ?? 'https://via.placeholder.com/150',
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readTime: data['readTime'] ?? '3 dk',
    );
  }
}

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  // --- STATE DEĞİŞKENLERİ ---
  String _selectedCategory = "Tümü"; 
  bool _isDescending = true; 

  final List<String> _categories = ["Tümü", "Rehberlik", "Ders Taktikleri", "Haberler", "Motivasyon"];

  @override
  Widget build(BuildContext context) {
    // --- TEMA AYARLARI ---
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF0A0E14) : const Color(0xFFF5F9FF);
    final textColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    final accentColor = isDarkMode ? const Color(0xFF448AFF) : Colors.blue;

    return Scaffold(
      extendBodyBehindAppBar: true, // Glass effect için body yukarı taşar
      backgroundColor: backgroundColor,
      
      // --- PREMIUM APP BAR ---
      appBar: AppBar(
        title: Text("DUS Rehberi", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: backgroundColor.withOpacity(0.7)),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isDescending = !_isDescending),
            icon: Icon(
              _isDescending ? Icons.sort_rounded : Icons.history_rounded,
              color: accentColor,
            ),
            tooltip: _isDescending ? "En Yeni" : "En Eski",
          ),
          const SizedBox(width: 8),
        ],
        automaticallyImplyLeading: false,
      ),
      
      body: Column(
        children: [
          // AppBar'ın arkasında kaldığı için üstten boşluk bırakıyoruz
          SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top),

          // --- KATEGORİ FİLTRESİ (PREMIUM CHIPS) ---
          Container(
            height: 60,
            color: Colors.transparent, 
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? accentColor 
                          : (isDarkMode ? const Color(0xFF161B22) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected 
                            ? Colors.transparent 
                            : (isDarkMode ? Colors.white10 : Colors.grey.shade300)
                      ),
                      boxShadow: isSelected 
                          ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] 
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- FIREBASE STREAM BUILDER ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('blog_posts')
                  .orderBy('publishedAt', descending: _isDescending)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Bir hata oluştu: ${snapshot.error}", style: TextStyle(color: textColor)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                List<BlogPost> allPosts = docs.map((doc) => BlogPost.fromFirestore(doc)).toList();

                // Filtreleme
                List<BlogPost> filteredPosts = allPosts;
                if (_selectedCategory != "Tümü") {
                  filteredPosts = allPosts.where((post) => post.category == _selectedCategory).toList();
                }

                if (filteredPosts.isEmpty) {
                  return _buildEmptyState(isDarkMode);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) {
                    return _buildBlogCard(filteredPosts[index], isDarkMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- PREMIUM BLOG KARTI ---
  Widget _buildBlogCard(BlogPost post, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final titleColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;
    final subTitleColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: isDarkMode ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resim Alanı
          Stack(
            children: [
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  image: DecorationImage(
                    image: NetworkImage(post.imageUrl),
                    fit: BoxFit.cover,
                    onError: (e, s) => debugPrint("Resim Hatası: $e"),
                  ),
                ),
                child: post.imageUrl.isEmpty 
                  ? Center(child: Icon(Icons.image_not_supported, color: subTitleColor)) 
                  : null,
              ),
              // Resim Üzeri Gradient (Yazı okunurluğu için opsiyonel, şık durur)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                    ),
                  ),
                ),
              ),
              // Kategori Etiketi (Resmin üzerinde)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9), // Glass efekt
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    post.category,
                    style: const TextStyle(
                      color: Color(0xFF1565C0), 
                      fontSize: 11, 
                      fontWeight: FontWeight.w800
                    ),
                  ),
                ),
              ),
            ],
          ),

          // İçerik
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: subTitleColor),
                    const SizedBox(width: 6),
                    Text(
                      "${post.publishedAt.day}.${post.publishedAt.month}.${post.publishedAt.year}",
                      style: TextStyle(color: subTitleColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time_rounded, size: 14, color: subTitleColor),
                    const SizedBox(width: 4),
                    Text(post.readTime, style: TextStyle(color: subTitleColor, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: titleColor, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                
                // "Oku" Butonu
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Devamını Oku", 
                      style: TextStyle(color: isDarkMode ? const Color(0xFF448AFF) : const Color(0xFF1565C0), fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: isDarkMode ? const Color(0xFF448AFF) : const Color(0xFF1565C0)),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 80, color: isDarkMode ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 20),
          Text(
            "Bu kategoride henüz yazı yok.",
            style: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}