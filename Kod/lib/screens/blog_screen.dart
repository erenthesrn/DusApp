import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// VERİ MODELİ
// =============================================================================
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
    final data = doc.data() as Map<String, dynamic>;
    return BlogPost(
      id: doc.id,
      title: data['title'] ?? 'Başlıksız',
      category: data['category'] ?? 'Genel',
      imageUrl: data['imageUrl'] ?? '',
      publishedAt: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readTime: data['readTime'] ?? '3 dk',
    );
  }
}

// =============================================================================
// DUS KAMPÜSÜ — ANA EKRAN
// =============================================================================
class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;

  // ── FIX: Stream'ler initState'de bir kez başlatılıyor, rebuild'da yeniden
  //         bağlantı açılmıyor → Firestore ASSERTION hatası önlendi.
  late Stream<DocumentSnapshot> _countdownStream;
  late Stream<QuerySnapshot> _blogStream;

  bool _isScrolled = false;
  String _selectedCategory = "Tümü";
  bool _isDescending = true;

  // Blog verileri state'de tutuluyor → scroll rebuild'da kaybolmuyor
  List<BlogPost> _allPosts = [];
  bool _blogLoading = true;
  String? _blogError;

  final List<String> _categories = ["Tümü", "Rehberlik", "Ders Taktikleri", "Haberler", "Motivasyon"];

  Color _categoryColor(String category) {
    switch (category) {
      case "Rehberlik":      return const Color(0xFF0969DA);
      case "Ders Taktikleri": return const Color(0xFF8A2BE2);
      case "Haberler":       return const Color(0xFFFF9500);
      case "Motivasyon":     return const Color(0xFF34C759);
      default:               return const Color(0xFF0969DA);
    }
  }

  @override
  void initState() {
    super.initState();

    // Stream'leri burada bir kez oluştur
    _countdownStream = FirebaseFirestore.instance
        .collection('app_config')
        .doc('dus_countdown')
        .snapshots();

    _blogStream = FirebaseFirestore.instance
        .collection('blog_posts')
        .orderBy('publishedAt', descending: _isDescending)
        .snapshots();

    // Blog stream'ini dinle ve state'e yaz
    _blogStream.listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _allPosts = snapshot.docs.map((d) => BlogPost.fromFirestore(d)).toList();
            _blogLoading = false;
            _blogError = null;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() { _blogError = e.toString(); _blogLoading = false; });
      },
    );

    _scrollController = ScrollController()
      ..addListener(() {
        final scrolled = _scrollController.offset > 50;
        if (scrolled != _isScrolled) setState(() => _isScrolled = scrolled);
      });

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
  }

  // Sıralama değişince yeni stream başlat (sadece bu durumda yeniden bağlanmak gerekiyor)
  void _toggleSort() {
    setState(() {
      _isDescending = !_isDescending;
      _blogLoading = true;
    });
    _blogStream = FirebaseFirestore.instance
        .collection('blog_posts')
        .orderBy('publishedAt', descending: _isDescending)
        .snapshots();

    _blogStream.listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _allPosts = snapshot.docs.map((d) => BlogPost.fromFirestore(d)).toList();
            _blogLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) setState(() { _blogError = e.toString(); _blogLoading = false; });
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF090A0F)
        : const Color.fromARGB(255, 224, 247, 250);

    List<BlogPost> filtered = _selectedCategory == "Tümü"
        ? _allPosts
        : _allPosts.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned(top: -100, left: -100, child: _buildAmbientBlob(const Color(0xFF0969DA), 300)),
          Positioned(top: 200, right: -150, child: _buildAmbientBlob(const Color(0xFF8A2BE2), 250)),

          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildCompactProgressCard(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              _buildSectionTitle("Hızlı Araçlar", isDark),
              _buildQuickActions(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              _buildCategoryFilter(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              _buildSectionTitleWithSort("Özel İçerikler", isDark),
              _buildBlogContent(filtered, isDark),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ATMOSFER
  // ===========================================================================
  Widget _buildAmbientBlob(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  // ===========================================================================
  // APP BAR
  // ===========================================================================
  SliverAppBar _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      floating: false, pinned: true, elevation: 0,
      backgroundColor: _isScrolled
          ? (isDark ? const Color(0xFF090A0F).withOpacity(0.9) : Colors.white.withOpacity(0.9))
          : Colors.transparent,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _isScrolled ? 20 : 0, sigmaY: _isScrolled ? 20 : 0),
          child: Container(color: Colors.transparent),
        ),
      ),
      title: Text("DUS Kampüsü",
          style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 20)),
      centerTitle: true,
      automaticallyImplyLeading: false,
    );
  }

  // ===========================================================================
  // PROGRESS KARTI — stream initState'de, burada sadece StreamBuilder kullanılıyor
  // ===========================================================================
  Widget _buildCompactProgressCard(bool isDark) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _animationController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: StreamBuilder<DocumentSnapshot>(
              stream: _countdownStream, // ← initState'deki sabit stream
              builder: (context, snapshot) {
                String label = "DUS 2026";
                String countdownText = "";

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  label = data['label'] ?? 'DUS 2026';
                  final examDate = (data['examDate'] as Timestamp?)?.toDate();
                  if (examDate != null) {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
                    final daysLeft = examDay.difference(today).inDays;
                    countdownText = daysLeft > 0
                        ? "Sınava $daysLeft Gün"
                        : daysLeft == 0 ? "Sınav Bugün! 🎯" : "Sınav geçti";
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                    boxShadow: [BoxShadow(color: const Color(0xFF0969DA).withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: const Color(0xFF8A2BE2).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                        ),
                        child: const Icon(Icons.rocket_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        countdownText.isEmpty ? label : "$label • $countdownText",
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.3),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION TITLES
  // ===========================================================================
  Widget _buildSectionTitle(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
        child: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
      ),
    );
  }

  Widget _buildSectionTitleWithSort(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
        child: Row(
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5)),
            const Spacer(),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); _toggleSort(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.07) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 14, color: isDark ? const Color(0xFF448AFF) : Colors.blue),
                    const SizedBox(width: 4),
                    Text(_isDescending ? "En Yeni" : "En Eski",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF448AFF) : Colors.blue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HIZLI ARAÇLAR — Puan butonu DUS Puan Hesaplayıcı'yı açıyor
  // ===========================================================================
  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {"icon": Icons.calculate_rounded,    "label": "Puan",    "color": const Color(0xFF0969DA)},
      {"icon": Icons.timer_rounded,        "label": "Sayaç",   "color": const Color(0xFFFF9500)},
      {"icon": Icons.analytics_rounded,    "label": "Tercih",  "color": const Color(0xFF34C759)},
      {"icon": Icons.calendar_month_rounded,"label": "Takvim", "color": const Color(0xFFAF52DE)},
    ];

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 110,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (index == 0) {
                  // Puan Hesaplayıcı
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => DusPuanHesaplayici(isDark: isDark),
                  );
                }
              },
              child: Container(
                width: 85,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (action["color"] as Color).withOpacity(0.2), width: 1),
                  boxShadow: [BoxShadow(color: (action["color"] as Color).withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: (action["color"] as Color).withOpacity(0.15), shape: BoxShape.circle),
                      child: Icon(action["icon"] as IconData, color: action["color"] as Color, size: 28),
                    ),
                    const SizedBox(height: 12),
                    Text(action["label"] as String,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // KATEGORİ FİLTRESİ
  // ===========================================================================
  Widget _buildCategoryFilter(bool isDark) {
    final accentColor = isDark ? const Color(0xFF448AFF) : Colors.blue;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 56,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final cat = _categories[index];
            final isSelected = cat == _selectedCategory;
            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedCategory = cat); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : (isDark ? const Color(0xFF161B22) : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)),
                  boxShadow: isSelected ? [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : [],
                ),
                child: Text(cat, style: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13,
                )),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // BLOG İÇERİĞİ — state'den gösteriliyor, stream bağlantısına bağlı değil
  // ===========================================================================
  Widget _buildBlogContent(List<BlogPost> filtered, bool isDark) {
    if (_blogLoading) return SliverToBoxAdapter(child: _buildShimmerList(isDark));
    if (_blogError != null) {
      return SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text("Hata: $_blogError", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45))),
      ));
    }
    if (filtered.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState(isDark));

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _buildHeroBlogCard(filtered[0], isDark),
            const SizedBox(height: 16),
            ...filtered.skip(1).map((post) => _buildCompactBlogCard(post, isDark)),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // HERO KARTI
  // ===========================================================================
  Widget _buildHeroBlogCard(BlogPost post, bool isDark) {
    final catColor = _categoryColor(post.category);
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        height: 340,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: catColor.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 16))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // FIX: gaplessPlayback + colorBlendMode ile resim rebuild'da beyaz kalmaz
              post.imageUrl.isNotEmpty
                  ? Image.network(
                      post.imageUrl,
                      fit: BoxFit.cover,
                      gaplessPlayback: true, // ← scroll'da eski frame korunur
                      cacheWidth: 800,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) return child;
                        return _buildImagePlaceholder(catColor);
                      },
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder(catColor),
                    )
                  : _buildImagePlaceholder(catColor),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.25), Colors.black.withOpacity(0.88)],
                    stops: const [0.15, 0.5, 1.0],
                  ),
                ),
              ),

              Positioned(
                left: 24, right: 24, bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(10)),
                      child: Text(post.category.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    ),
                    const SizedBox(height: 12),
                    Text(post.title,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.5),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(post.readTime, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text("${post.publishedAt.day}.${post.publishedAt.month}.${post.publishedAt.year}",
                            style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: const Row(children: [
                            Text("Oku", style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black87),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // KOMPAKT KART
  // ===========================================================================
  Widget _buildCompactBlogCard(BlogPost post, bool isDark) {
    final catColor = _categoryColor(post.category);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final titleColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final subColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 80, height: 80,
                child: post.imageUrl.isNotEmpty
                    ? Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                        gaplessPlayback: true, // ← FIX
                        cacheWidth: 200,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) return child;
                          return _buildSmallPlaceholder(catColor);
                        },
                        errorBuilder: (_, __, ___) => _buildSmallPlaceholder(catColor),
                      )
                    : _buildSmallPlaceholder(catColor),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: catColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(post.category, style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                  ]),
                  const SizedBox(height: 6),
                  Text(post.title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 12, color: subColor),
                    const SizedBox(width: 4),
                    Text(post.readTime, style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text("${post.publishedAt.day}.${post.publishedAt.month}.${post.publishedAt.year}",
                        style: TextStyle(color: subColor, fontSize: 11)),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // YARDIMCI WIDGET'LAR
  // ===========================================================================
  Widget _buildImagePlaceholder(Color catColor) => Container(
    color: catColor.withOpacity(0.15),
    child: Center(child: Icon(Icons.article_rounded, color: catColor.withOpacity(0.4), size: 60)),
  );

  Widget _buildSmallPlaceholder(Color catColor) => Container(
    color: catColor.withOpacity(0.12),
    child: Center(child: Icon(Icons.article_rounded, color: catColor.withOpacity(0.4), size: 28)),
  );

  Widget _buildShimmerList(bool isDark) {
    final base = isDark ? const Color(0xFF1A2030) : Colors.grey.shade200;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        Container(height: 340, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(28))),
        const SizedBox(height: 16),
        ...List.generate(3, (_) => Container(
          margin: const EdgeInsets.only(bottom: 12), height: 112,
          decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20)),
        )),
      ]),
    );
  }

  Widget _buildEmptyState(bool isDark) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.article_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[300]),
      const SizedBox(height: 20),
      Text("Bu kategoride henüz yazı yok.",
          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)),
    ])),
  );
}


// =============================================================================
// DUS PUAN HESAPLAYICI — Resmi ÖSYM Formülü (TBT + KBT Ayrı)
// =============================================================================
//
// TEST YAPISI:
//   TBT (Temel Bilimler Testi) : 40 soru
//   KBT (Klinik Bilimler Testi): 80 soru
//
// HESAPLAMA ADIMLARI:
//   1. Net = Doğru − (Yanlış / 4)   [TBT ve KBT için ayrı]
//   2. Standart Puan = 50 + 10 × ((Net − Ort) / SS)
//   3. K Puanı = (TBT_SP × 0.4) + (KBT_SP × 0.6)
//      T Puanı = (TBT_SP × 0.6) + (KBT_SP × 0.4)
//   4. %5 kesinti (isteğe bağlı)
//
// VARSAYILAN SABİTLER (ÖSYM sonuçlarıyla güncellenir):
//   TBT Ort: 14.0  |  TBT SS: 6.5
//   KBT Ort: 38.0  |  KBT SS: 14.0
// =============================================================================

class DusPuanHesaplayici extends StatefulWidget {
  final bool isDark;
  const DusPuanHesaplayici({super.key, required this.isDark});

  @override
  State<DusPuanHesaplayici> createState() => _DusPuanHesaplayiciState();
}

class _DusPuanHesaplayiciState extends State<DusPuanHesaplayici>
    with SingleTickerProviderStateMixin {
  // ── Soru limitleri ──────────────────────────────────────────────────────────
  static const int _tbtLimit = 40;
  static const int _kbtLimit = 80;

  // ── Varsayılan sabitler (ÖSYM kılavuzuna göre tahmini) ──────────────────────
  static const double _tbtOrt = 14.0;
  static const double _tbtSS  = 6.5;
  static const double _kbtOrt = 38.0;
  static const double _kbtSS  = 14.0;

  // ── Text controller'lar ─────────────────────────────────────────────────────
  final _tbtD = TextEditingController();
  final _tbtY = TextEditingController();
  final _kbtD = TextEditingController();
  final _kbtY = TextEditingController();

  // ── State ───────────────────────────────────────────────────────────────────
  bool _kesinti     = false;
  bool _hesaplandi  = false;

  // ── Sonuçlar ────────────────────────────────────────────────────────────────
  double _tbtNet = 0, _kbtNet = 0;
  double _tbtSP  = 0, _kbtSP  = 0;
  double _kPuani = 0, _tPuani = 0;
  double _kKesin = 0, _tKesin = 0;

  // ── Animasyon ───────────────────────────────────────────────────────────────
  late AnimationController _animCtrl;
  late Animation<double>   _animFade;
  late Animation<Offset>   _animSlide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animFade  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _animSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _tbtD.dispose(); _tbtY.dispose();
    _kbtD.dispose(); _kbtY.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Yardımcı: Sayısal değer okuma ───────────────────────────────────────────
  int _val(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

  // ── Hesaplama motoru ────────────────────────────────────────────────────────
  void _hesapla() {
    final tD = _val(_tbtD); final tY = _val(_tbtY);
    final kD = _val(_kbtD); final kY = _val(_kbtY);

    // ── Doğrulama ────────────────────────────────────────────────────────────
    if (tD < 0 || tY < 0 || kD < 0 || kY < 0) {
      _snack("Negatif değer girilemez.", Colors.redAccent); return;
    }
    if (tD + tY > _tbtLimit) {
      _snack("TBT: Doğru + Yanlış toplamı $_tbtLimit soruyu geçemez!", Colors.redAccent); return;
    }
    if (kD + kY > _kbtLimit) {
      _snack("KBT: Doğru + Yanlış toplamı $_kbtLimit soruyu geçemez!", Colors.redAccent); return;
    }

    // ── Adım 1: Net (Ham Puan) ───────────────────────────────────────────────
    final tbtNet = tD - (tY / 4.0);
    final kbtNet = kD - (kY / 4.0);

    // ── Adım 2: Standart Puan ────────────────────────────────────────────────
    final tbtSP = 50.0 + 10.0 * ((tbtNet - _tbtOrt) / _tbtSS);
    final kbtSP = 50.0 + 10.0 * ((kbtNet - _kbtOrt) / _kbtSS);

    // ── Adım 3: Ağırlıklı Puanlar ───────────────────────────────────────────
    final kPuan = (tbtSP * 0.4) + (kbtSP * 0.6);
    final tPuan = (tbtSP * 0.6) + (kbtSP * 0.4);

    // ── Adım 4: %5 kesinti ───────────────────────────────────────────────────
    final kKesin = _kesinti ? kPuan * 0.95 : kPuan;
    final tKesin = _kesinti ? tPuan * 0.95 : tPuan;

    HapticFeedback.mediumImpact();
    setState(() {
      _tbtNet = tbtNet; _kbtNet = kbtNet;
      _tbtSP  = tbtSP;  _kbtSP  = kbtSP;
      _kPuani = kPuan;  _tPuani = tPuan;
      _kKesin = kKesin; _tKesin = tKesin;
      _hesaplandi = true;
    });
    _animCtrl.forward(from: 0);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  // ── Puan → renk ─────────────────────────────────────────────────────────────
  Color _puanRenk(double p) {
    if (p >= 70) return const Color(0xFF34C759);
    if (p >= 60) return const Color(0xFFFF9F0A);
    if (p >= 50) return const Color(0xFFFF6B35);
    return const Color(0xFFFF3B30);
  }

  // ── Puan → yorum ─────────────────────────────────────────────────────────────
  String _puanYorum(double p) {
    if (p >= 75) return "Mükemmel · Çoğu program tercih edilebilir 🏆";
    if (p >= 65) return "Çok İyi · Geniş tercih seçeneği 🎯";
    if (p >= 55) return "İyi · Çeşitli devlet programları ✅";
    if (p >= 45) return "Orta · Sınırlı seçenekler 📚";
    return "Düşük · Daha fazla çalışma gerekiyor ⚡";
  }

  // ============================================================================
  // BUILD
  // ============================================================================
  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    final bg        = isDark ? const Color(0xFF0D1117) : Colors.white;
    final surface   = isDark ? const Color(0xFF161B22) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Başlık ────────────────────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFF0969DA).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("DUS Puan Hesaplayıcı",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
                Text("ÖSYM resmi formülü · TBT + KBT",
                    style: TextStyle(fontSize: 12, color: subColor)),
              ]),
            ]),

            const SizedBox(height: 28),

            // ── TBT Girişi ────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.science_outlined,
              label: "Temel Bilimler Testi (TBT)",
              badge: "40 soru",
              color: const Color(0xFF0969DA),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _TestInputRow(
              dCtrl: _tbtD, yCtrl: _tbtY,
              limit: _tbtLimit,
              accentColor: const Color(0xFF0969DA),
              surface: surface, textColor: textColor, isDark: isDark,
              onChanged: () => setState(() {}),
            ),

            const SizedBox(height: 20),

            // ── KBT Girişi ────────────────────────────────────────────────────
            _SectionHeader(
              icon: Icons.local_hospital_outlined,
              label: "Klinik Bilimler Testi (KBT)",
              badge: "80 soru",
              color: const Color(0xFF8A2BE2),
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _TestInputRow(
              dCtrl: _kbtD, yCtrl: _kbtY,
              limit: _kbtLimit,
              accentColor: const Color(0xFF8A2BE2),
              surface: surface, textColor: textColor, isDark: isDark,
              onChanged: () => setState(() {}),
            ),

            const SizedBox(height: 20),

            // ── %5 Kesinti Toggle ─────────────────────────────────────────────
            GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); setState(() => _kesinti = !_kesinti); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _kesinti ? const Color(0xFFFF9500).withOpacity(0.1) : surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _kesinti ? const Color(0xFFFF9500) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  // Özel checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: _kesinti ? const Color(0xFFFF9500) : (isDark ? Colors.white12 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _kesinti ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      "Uzmanlık eğitimime devam ediyorum",
                      style: TextStyle(
                        color: _kesinti ? const Color(0xFFFF9500) : textColor,
                        fontSize: 14, fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      "Hesaplanan K ve T puanlarına %5 kesinti uygulanır",
                      style: TextStyle(fontSize: 11, color: subColor, height: 1.4),
                    ),
                  ])),
                  const SizedBox(width: 8),
                  if (_kesinti)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(8)),
                      child: const Text("−%5", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // ── Hesapla Butonu ────────────────────────────────────────────────
            GestureDetector(
              onTap: _hesapla,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0969DA).withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Puanı Hesapla",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ]),
              ),
            ),

            // ── Sonuçlar ──────────────────────────────────────────────────────
            if (_hesaplandi) ...[
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _animFade,
                child: SlideTransition(
                  position: _animSlide,
                  child: _buildResults(isDark, surface, textColor, subColor),
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Sonuç Kartları ──────────────────────────────────────────────────────────
  Widget _buildResults(bool isDark, Color surface, Color textColor, Color subColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ana puan kartları yan yana
        Row(children: [
          Expanded(child: _MainPuanKarti(
            label: "Klinik Puanı",
            sublabel: "K Puanı",
            puan: _kKesin,
            hamPuan: _kPuani,
            kesintiVar: _kesinti,
            color: const Color(0xFF8A2BE2),
            yorum: _puanYorum(_kKesin),
            isDark: isDark,
            puanRenk: _puanRenk(_kKesin),
          )),
          const SizedBox(width: 12),
          Expanded(child: _MainPuanKarti(
            label: "Temel Puanı",
            sublabel: "T Puanı",
            puan: _tKesin,
            hamPuan: _tPuani,
            kesintiVar: _kesinti,
            color: const Color(0xFF0969DA),
            yorum: _puanYorum(_tKesin),
            isDark: isDark,
            puanRenk: _puanRenk(_tKesin),
          )),
        ]),

        const SizedBox(height: 16),

        // Ara hesaplama detayları
        _DetayKarti(
          isDark: isDark,
          surface: surface,
          textColor: textColor,
          subColor: subColor,
          tbtNet: _tbtNet, kbtNet: _kbtNet,
          tbtSP: _tbtSP,   kbtSP: _kbtSP,
          kHam: _kPuani,   tHam: _tPuani,
          kesinti: _kesinti,
        ),

        const SizedBox(height: 12),

        // Bilgi notu
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0969DA).withOpacity(0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF0969DA).withOpacity(0.15)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF0969DA)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              "Standart puan hesabında kullanılan ortalama (TBT: 14, KBT: 38) ve standart sapma (TBT: 6.5, KBT: 14) değerleri tahminidir. "
              "ÖSYM, gerçek değerleri sınav sonuçlarıyla birlikte açıklar.",
              style: const TextStyle(fontSize: 11, color: Color(0xFF0969DA), height: 1.5, fontWeight: FontWeight.w500),
            )),
          ]),
        ),
      ],
    );
  }
}

// =============================================================================
// YARDIMCI WIDGET — Bölüm Başlığı
// =============================================================================
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label, badge;
  final Color color;
  final bool isDark;

  const _SectionHeader({
    required this.icon, required this.label, required this.badge,
    required this.color, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

// =============================================================================
// YARDIMCI WIDGET — Test Giriş Satırı (D/Y + boş sayacı)
// =============================================================================
class _TestInputRow extends StatelessWidget {
  final TextEditingController dCtrl, yCtrl;
  final int limit;
  final Color accentColor, surface, textColor;
  final bool isDark;
  final VoidCallback onChanged;

  const _TestInputRow({
    required this.dCtrl, required this.yCtrl, required this.limit,
    required this.accentColor, required this.surface,
    required this.textColor, required this.isDark, required this.onChanged,
  });

  int get _d => int.tryParse(dCtrl.text.trim()) ?? 0;
  int get _y => int.tryParse(yCtrl.text.trim()) ?? 0;
  int get _bos => (limit - _d - _y).clamp(0, limit);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: _NumField(
          controller: dCtrl, label: "Doğru",
          icon: Icons.check_circle_outline,
          color: const Color(0xFF34C759),
          surface: surface, textColor: textColor, isDark: isDark,
          onChanged: onChanged,
        )),
        const SizedBox(width: 10),
        Expanded(child: _NumField(
          controller: yCtrl, label: "Yanlış",
          icon: Icons.cancel_outlined,
          color: const Color(0xFFFF3B30),
          surface: surface, textColor: textColor, isDark: isDark,
          onChanged: onChanged,
        )),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.remove_circle_outline, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          const SizedBox(width: 6),
          Text("Boş: $_bos", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          // Mini progress bar
          SizedBox(
            width: 80, height: 6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(children: [
                Container(color: isDark ? Colors.white10 : Colors.grey.shade200),
                FractionallySizedBox(
                  widthFactor: ((_d + _y) / limit).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: (_d + _y) > limit ? Colors.red : accentColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Text("${_d + _y}/$limit",
              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600], fontWeight: FontWeight.w500)),
        ]),
      ),
    ]);
  }
}

// =============================================================================
// YARDIMCI WIDGET — Sayısal Giriş Alanı
// =============================================================================
class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color, surface, textColor;
  final bool isDark;
  final VoidCallback onChanged;

  const _NumField({
    required this.controller, required this.label, required this.icon,
    required this.color, required this.surface, required this.textColor,
    required this.isDark, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (_) => onChanged(),
        style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          hintText: "0",
          hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 22),
          filled: true, fillColor: surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: color, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ]);
  }
}

// =============================================================================
// YARDIMCI WIDGET — Ana Puan Kartı
// =============================================================================
class _MainPuanKarti extends StatelessWidget {
  final String label, sublabel, yorum;
  final double puan, hamPuan;
  final bool kesintiVar, isDark;
  final Color color, puanRenk;

  const _MainPuanKarti({
    required this.label, required this.sublabel, required this.yorum,
    required this.puan, required this.hamPuan, required this.kesintiVar,
    required this.color, required this.isDark, required this.puanRenk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(isDark ? 0.25 : 0.08), color.withOpacity(isDark ? 0.12 : 0.03)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Etiket + icon
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(
              label.contains("Klinik") ? Icons.local_hospital_rounded : Icons.science_rounded,
              size: 14, color: color,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(sublabel,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3))),
        ]),
        const SizedBox(height: 10),
        // Puan
        Text(
          puan.toStringAsFixed(3),
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: puanRenk, height: 1.0, letterSpacing: -1),
        ),
        const SizedBox(height: 2),
        Text("/ 100", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])),
        // Kesinti göstergesi
        if (kesintiVar) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFFF9500).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(
              "Ham: ${hamPuan.toStringAsFixed(2)} → −%5",
              style: const TextStyle(fontSize: 10, color: Color(0xFFFF9500), fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Puan çubuğu
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            Container(height: 6, color: isDark ? Colors.white10 : Colors.grey.shade200),
            FractionallySizedBox(
              widthFactor: (puan / 100).clamp(0.0, 1.0),
              child: Container(height: 6,
                decoration: BoxDecoration(color: puanRenk, borderRadius: BorderRadius.circular(4))),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(yorum, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600], height: 1.4)),
      ]),
    );
  }
}

// =============================================================================
// YARDIMCI WIDGET — Ara Hesaplama Detay Kartı
// =============================================================================
class _DetayKarti extends StatefulWidget {
  final bool isDark, kesinti;
  final Color surface, textColor, subColor;
  final double tbtNet, kbtNet, tbtSP, kbtSP, kHam, tHam;

  const _DetayKarti({
    required this.isDark, required this.surface, required this.textColor,
    required this.subColor, required this.kesinti,
    required this.tbtNet, required this.kbtNet,
    required this.tbtSP, required this.kbtSP,
    required this.kHam, required this.tHam,
  });

  @override
  State<_DetayKarti> createState() => _DetayKartiState();
}

class _DetayKartiState extends State<_DetayKarti> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(children: [
        // Başlık / toggle
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); setState(() => _acik = !_acik); },
          child: Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF0969DA)),
              const SizedBox(width: 8),
              Text("Hesaplama Detayları",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.textColor)),
              const Spacer(),
              AnimatedRotation(
                turns: _acik ? 0.5 : 0,
                duration: const Duration(milliseconds: 250),
                child: Icon(Icons.keyboard_arrow_down_rounded, color: widget.subColor),
              ),
            ]),
          ),
        ),

        // İçerik
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _acik ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              Divider(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
              const SizedBox(height: 8),

              // TBT
              _DetayBlok(
                baslik: "TBT (Temel Bilimler)", renk: const Color(0xFF0969DA), isDark: widget.isDark, subColor: widget.subColor,
                satirlar: [
                  ("Net (Ham Puan)", "${widget.tbtNet.toStringAsFixed(2)} = D − Y÷4"),
                  ("Standart Puan", "${widget.tbtSP.toStringAsFixed(3)} = 50 + 10×((Net−14)/6.5)"),
                ],
              ),
              const SizedBox(height: 12),

              // KBT
              _DetayBlok(
                baslik: "KBT (Klinik Bilimler)", renk: const Color(0xFF8A2BE2), isDark: widget.isDark, subColor: widget.subColor,
                satirlar: [
                  ("Net (Ham Puan)", "${widget.kbtNet.toStringAsFixed(2)} = D − Y÷4"),
                  ("Standart Puan", "${widget.kbtSP.toStringAsFixed(3)} = 50 + 10×((Net−38)/14)"),
                ],
              ),
              const SizedBox(height: 12),

              // Ağırlıklı
              _DetayBlok(
                baslik: "Ağırlıklı Puanlar", renk: const Color(0xFF34C759), isDark: widget.isDark, subColor: widget.subColor,
                satirlar: [
                  ("K Puanı (ham)", "${widget.kHam.toStringAsFixed(3)} = TBT×0.4 + KBT×0.6"),
                  ("T Puanı (ham)", "${widget.tHam.toStringAsFixed(3)} = TBT×0.6 + KBT×0.4"),
                  if (widget.kesinti) ("Kesinti sonrası", "${(widget.kHam * 0.95).toStringAsFixed(3)} / ${(widget.tHam * 0.95).toStringAsFixed(3)}"),
                ],
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DetayBlok extends StatelessWidget {
  final String baslik;
  final Color renk;
  final bool isDark;
  final Color subColor;
  final List<(String, String)> satirlar;

  const _DetayBlok({
    required this.baslik, required this.renk, required this.isDark,
    required this.subColor, required this.satirlar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(baslik, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: renk)),
      ]),
      const SizedBox(height: 8),
      ...satirlar.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            child: Text(s.$1, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(s.$2,
              style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w600))),
        ]),
      )),
    ]);
  }
}
