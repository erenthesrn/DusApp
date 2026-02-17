import 'dart:async';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // HapticFeedback için
import '../admin/question_uploader.dart';

// -----------------------------------------------------------------------------
// 1. VERİ MODELİ
// -----------------------------------------------------------------------------
class BlogPost {
  final String id;
  final String title;
  final String content;
  final String category;
  final String imageUrl;
  final DateTime publishedAt;
  final String readTime;
  final bool isAudioAvailable;

  BlogPost({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.imageUrl,
    required this.publishedAt,
    required this.readTime,
    this.isAudioAvailable = false,
  });

  factory BlogPost.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return BlogPost(
      id: doc.id,
      title: data['title'] ?? 'Başlıksız İçerik',
      content: data['content'] ?? 'İçerik yüklenemedi.',
      category: data['category'] ?? 'Genel',
      imageUrl: data['imageUrl'] ?? 'https://images.unsplash.com/photo-1584515933487-9d317552d894?auto=format&fit=crop&w=800&q=80',
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readTime: data['readTime'] ?? '3 dk',
      isAudioAvailable: data['isAudioAvailable'] ?? false,
    );
  }
}

// -----------------------------------------------------------------------------
// 2. ANA EKRAN (BLOG SCREEN -> DUS KAMPÜSÜ)
// -----------------------------------------------------------------------------
class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> with TickerProviderStateMixin {
  
  // --- STATE ---
  String _selectedCategory = "Tümü";
  final List<String> _categories = ["Tümü", "Rehberlik", "Ders Taktikleri", "Haberler", "Motivasyon"];
  
  // Animasyonlar
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Vaka Kartı State
  bool _isCaseRevealed = false;

  // SMART NOTES (AKIL NOTLARI) VERİSİ
  final List<Map<String, dynamic>> _smartNotes = [
    {
      "title": "N. Facialis Dalları",
      "note": "T-Z-B-M-C\n(Temporal, Zigomatik, Bukkal, Mandibular, Servikal)",
      "color": const Color(0xFFFFE0B2), // Açık Turuncu
      "textColor": const Color(0xFFE65100)
    },
    {
      "title": "Sifilis Evreleri",
      "note": "Şanslı Güller Lastik Sever\n(Şankr, Gül, Latent, Gom)",
      "color": const Color(0xFFE1BEE7), // Açık Mor
      "textColor": const Color(0xFF4A148C)
    },
    {
      "title": "Lokal Anestezikler",
      "note": "Amid grubu 'i' harfini iki kere içerir.\nÖrn: Lidokain, Bupivakain.",
      "color": const Color(0xFFC8E6C9), // Açık Yeşil
      "textColor": const Color(0xFF1B5E20)
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF2F5F8);
    final titleColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328);
    final accentColor = const Color(0xFF0969DA);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // --- APP BAR ---
          SliverAppBar(
            backgroundColor: bgColor,
            expandedHeight: 100.0,
            floating: true,
            pinned: true,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DUS Rehberi",
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: -0.5,
                    ),
                  ),
                  // Canlı Sayaç
                  Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.greenAccent, blurRadius: 5)]
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "1,234 kişi çalışıyor",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.w500
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: isDark ? Colors.white10 : Colors.white,
                  child: Icon(Icons.search, size: 20, color: titleColor),
                ),
              )
            ],
          ),

          // --- 1. SMART NOTES (AKIL NOTLARI) ---
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Text("Smart Notes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: titleColor)),
                      const Spacer(),
                      Text("Tümü", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _smartNotes.length,
                    itemBuilder: (context, index) {
                      final note = _smartNotes[index];
                      return _buildSmartNoteCard(note);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // --- 🔥 YENİ: HIZLI ERİŞİM BUTONLARI ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickAccessItem(Icons.calculate_outlined, "Puan\nHesapla", Colors.blue, isDark),
                    _buildQuickAccessItem(Icons.timer_outlined, "Sınav\nSayacı", Colors.orange, isDark),
                    _buildQuickAccessItem(Icons.smart_toy_outlined, "Tercih\nRobotu", Colors.purple, isDark),
                    _buildQuickAccessItem(Icons.calendar_month_outlined, "Sınav\nTakvimi", Colors.teal, isDark),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // --- 2. GÜNÜN VAKASI (INTERACTIVE) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCaseOfTheDay(isDark),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // --- 3. KATEGORİ SEÇİCİ ---
          SliverToBoxAdapter(
            child: Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      decoration: BoxDecoration(
                        color: isSelected ? accentColor : (isDark ? const Color(0xFF161B22) : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // --- 4. BLOG AKIŞI ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('blog_posts').orderBy('publishedAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Text("Hata: ${snapshot.error}")));
              if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));

              final docs = snapshot.data!.docs;
              List<BlogPost> posts = docs.map((d) => BlogPost.fromFirestore(d)).toList();
              
              if (_selectedCategory != "Tümü") {
                posts = posts.where((p) => p.category == _selectedCategory).toList();
              }

              if (posts.isEmpty) {
                 return SliverToBoxAdapter(
                   child: Padding(
                     padding: const EdgeInsets.all(40.0),
                     child: Column(
                       children: [
                         Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                         const SizedBox(height: 10),
                         Text("Henüz yazı eklenmemiş.", style: TextStyle(color: Colors.grey.shade500)),
                       ],
                     ),
                   ),
                 );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildBlogCard(posts[index], isDark),
                      );
                    },
                    childCount: posts.length,
                  ),
                ),
              );
            },
          ),
          
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      
      floatingActionButton: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.cloud_upload_rounded),
        onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yükleniyor...")));
        },
      ),
    );
  }

  // --- WIDGETS ---

  // 🔥 YENİ: HIZLI ERİŞİM BUTONU WIDGET'I
  Widget _buildQuickAccessItem(IconData icon, String label, Color color, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Burada ilgili araçlara navigasyon yapılacak (Şimdilik SnackBar)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label yakında aktif!")));
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              height: 1.1
            ),
          ),
        ],
      ),
    );
  }

  // 1. SMART NOTE KARTI (Post-it Tarzı)
  Widget _buildSmartNoteCard(Map<String, dynamic> note) {
    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: note['color'],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, size: 14, color: note['textColor']),
              const Spacer(),
              Icon(Icons.copy_rounded, size: 14, color: note['textColor'].withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note['title'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: note['textColor'],
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              note['note'],
              style: TextStyle(
                color: note['textColor'].withOpacity(0.9),
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w600
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. GÜNÜN VAKASI (Interactive Case)
  Widget _buildCaseOfTheDay(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _isCaseRevealed ? Colors.green.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.blue.withOpacity(0.1)), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text("GÜNÜN VAKASI", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              const Icon(Icons.medical_services_outlined, size: 18, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "25 yaşında erkek hasta, diş ağrısı şikayetiyle başvuruyor. Ağrı özellikle soğukta artıyor ve uyaran kalkınca hemen geçiyor. Radyografta çürük pulpaya yakın.",
            style: TextStyle(fontSize: 14, height: 1.4, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 16),
          
          if (!_isCaseRevealed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                  elevation: 0,
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isCaseRevealed = true);
                },
                child: const Text("Tanıyı Gör", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("Tanı: Reversible Pulpitis", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 4),
                  Text("Tedavi: Çürük temizlenir, kuafaj veya dolgu yapılır.", style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
            )
        ],
      ),
    );
  }

  // 3. BLOG KARTI (Daha kompakt ve şık)
  Widget _buildBlogCard(BlogPost post, bool isDark) {
    return GestureDetector(
      onTap: () => _openBlogDetail(post, isDark),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Resim
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Image.network(post.imageUrl, width: 110, height: 110, fit: BoxFit.cover),
            ),
            
            // İçerik
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(post.category.toUpperCase(), style: const TextStyle(color: Color(0xFF0969DA), fontSize: 10, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if(post.isAudioAvailable) const Icon(Icons.headphones, size: 14, color: Colors.orange),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(post.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold, height: 1.2)),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(post.readTime, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // DETAY SAYFASI
  void _openBlogDetail(BlogPost post, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: post.id,
                      child: Container(
                        height: 300,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                          image: DecorationImage(image: NetworkImage(post.imageUrl), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10, right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black54),
                        style: IconButton.styleFrom(backgroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: const Color(0xFF0969DA).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(post.category, style: const TextStyle(color: Color(0xFF0969DA), fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(post.readTime, style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        post.title,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, height: 1.2),
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      Text(
                        post.content,
                        style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}