import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'blog_screen.dart'; // BlogPost modelini import et

// =============================================================================
// BLOG DETAY / OKUMA EKRANI
// =============================================================================
// Firebase'de blog_posts/{id} dökümanına şu field'ı ekle:
//   content : String — Yazının tam metni
//
// Metin formatı (opsiyonel markdown benzeri):
//   ## Başlık      → Bölüm başlığı
//   **bold metin** → Kalın yazı (henüz plain text, genişletilebilir)
//   Boş satır      → Paragraf arası boşluk
// =============================================================================

class BlogDetailScreen extends StatefulWidget {
  final BlogPost post;
  const BlogDetailScreen({super.key, required this.post});

  @override
  State<BlogDetailScreen> createState() => _BlogDetailScreenState();
}

class _BlogDetailScreenState extends State<BlogDetailScreen> {
  late ScrollController _scrollController;
  double _scrollProgress = 0.0;
  bool _headerVisible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final offset = _scrollController.offset;
        final maxScroll = _scrollController.position.maxScrollExtent;

        // İlerleme çubuğu
        if (maxScroll > 0) {
          setState(() => _scrollProgress = (offset / maxScroll).clamp(0.0, 1.0));
        }

        // Header gizle/göster
        if (offset > _lastOffset + 8 && offset > 80) {
          if (_headerVisible) setState(() => _headerVisible = false);
        } else if (offset < _lastOffset - 8) {
          if (!_headerVisible) setState(() => _headerVisible = true);
        }
        _lastOffset = offset;
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case "Rehberlik":       return const Color(0xFF0969DA);
      case "Ders Taktikleri": return const Color(0xFF8A2BE2);
      case "Haberler":        return const Color(0xFFFF9500);
      case "Motivasyon":      return const Color(0xFF34C759);
      default:                return const Color(0xFF0969DA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final post     = widget.post;
    final catColor = _categoryColor(post.category);
    final bg       = isDark ? const Color(0xFF090A0F) : const Color(0xFFFAFBFC);
    final textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1A1A2E);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── İçerik ─────────────────────────────────────────────────────────
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero resim + başlık
              _buildHeroSliver(context, isDark, post, catColor),

              // İçerik
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                  child: post.content.isEmpty
                      ? _buildEmptyContent(isDark)
                      : _buildContent(post.content, isDark, textColor),
                ),
              ),
            ],
          ),

          // ── Üst navigasyon (AppBar yerine custom) ──────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            top: _headerVisible ? 0 : -100,
            left: 0, right: 0,
            child: _buildTopBar(context, isDark, post),
          ),

          // ── Alt ilerleme çubuğu ───────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildProgressBar(isDark, catColor),
          ),
        ],
      ),
    );
  }

  // ── Hero Sliver ─────────────────────────────────────────────────────────────
  Widget _buildHeroSliver(BuildContext ctx, bool isDark, BlogPost post, Color catColor) {
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          // Hero resim
          SizedBox(
            height: 320,
            width: double.infinity,
            child: post.imageUrl.isNotEmpty
                ? Image.network(
                    post.imageUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => _imageFallback(catColor),
                  )
                : _imageFallback(catColor),
          ),

          // Gradient üstü
          Container(
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.35),
                  Colors.transparent,
                  Colors.transparent,
                  (isDark ? const Color(0xFF090A0F) : const Color(0xFFFAFBFC)).withOpacity(0.95),
                  isDark ? const Color(0xFF090A0F) : const Color(0xFFFAFBFC),
                ],
                stops: const [0.0, 0.2, 0.55, 0.85, 1.0],
              ),
            ),
          ),

          // Kategori + başlık (resmin üzerinde alt kısımda)
          Positioned(
            left: 24, right: 24, bottom: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kategori badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: catColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    post.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 10,
                      fontWeight: FontWeight.w900, letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Başlık
                Text(
                  post.title,
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    height: 1.25, letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                // Meta bilgiler
                Row(children: [
                  _metaChip(
                    Icons.access_time_rounded,
                    post.readTime,
                    isDark,
                  ),
                  const SizedBox(width: 12),
                  _metaChip(
                    Icons.calendar_today_rounded,
                    "${post.publishedAt.day}.${post.publishedAt.month}.${post.publishedAt.year}",
                    isDark,
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, bool isDark) {
    return Row(children: [
      Icon(icon, size: 13, color: isDark ? Colors.grey[500] : Colors.grey[500]),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          )),
    ]);
  }

  // ── İçerik Render ──────────────────────────────────────────────────────────
  Widget _buildContent(String rawContent, bool isDark, Color textColor) {
    final paragraphs = rawContent.split('\n');
    final List<Widget> widgets = [];

    for (final line in paragraphs) {
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // ## Başlık
      if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(
            trimmed.substring(3),
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: textColor, height: 1.3, letterSpacing: -0.3,
            ),
          ),
        ));
        continue;
      }

      // # Ana başlık
      if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: Text(
            trimmed.substring(2),
            style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900,
              color: textColor, height: 1.2, letterSpacing: -0.5,
            ),
          ),
        ));
        continue;
      }

      // > Alıntı
      if (trimmed.startsWith('> ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0969DA).withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: const Border(
                left: BorderSide(color: Color(0xFF0969DA), width: 3),
              ),
            ),
            child: Text(
              trimmed.substring(2),
              style: const TextStyle(
                fontSize: 15, height: 1.6, fontStyle: FontStyle.italic,
                color: Color(0xFF0969DA), fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ));
        continue;
      }

      // - Madde işareti
      if (trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0969DA),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                trimmed.substring(2),
                style: TextStyle(
                  fontSize: 16, height: 1.7,
                  color: isDark ? Colors.grey[300] : const Color(0xFF2D3748),
                ),
              )),
            ],
          ),
        ));
        continue;
      }

      // Normal paragraf
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          trimmed,
          style: TextStyle(
            fontSize: 16, height: 1.75,
            color: isDark ? Colors.grey[300] : const Color(0xFF2D3748),
            letterSpacing: 0.1,
          ),
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildEmptyContent(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(children: [
          Icon(Icons.article_outlined, size: 64,
              color: isDark ? Colors.white12 : Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "İçerik henüz eklenmemiş.",
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Firebase'de bu yazının 'content' alanını doldurun.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext ctx, bool isDark, BlogPost post) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 8,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(children: [
        // Geri butonu
        GestureDetector(
          onTap: () { HapticFeedback.lightImpact(); Navigator.pop(ctx); },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
          ),
        ),
        const Spacer(),
        // Paylaş butonu
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: const Text("Paylaşım özelliği yakında!"),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }

  // ── Alt ilerleme çubuğu ────────────────────────────────────────────────────
  Widget _buildProgressBar(bool isDark, Color catColor) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.grey.shade200,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _scrollProgress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF0969DA), catColor],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageFallback(Color catColor) => Container(
    color: catColor.withOpacity(0.15),
    child: Center(child: Icon(Icons.article_rounded,
        color: catColor.withOpacity(0.3), size: 80)),
  );
}
