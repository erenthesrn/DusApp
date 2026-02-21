import 'dart:math'; // Animasyon hesaplamaları için eklendi
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// -----------------------------------------------------------------------------
// DUS REHBERİ (COGNITIVE OASIS) - ANA EKRAN
// -----------------------------------------------------------------------------
class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        if (_scrollController.offset > 50 && !_isScrolled) {
          setState(() => _isScrolled = true);
        } else if (_scrollController.offset <= 50 && _isScrolled) {
          setState(() => _isScrolled = false);
        }
      });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
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
    final backgroundColor = isDark ? const Color(0xFF090A0F) : const Color(0xFFF4F6F9);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Arka Plandaki Atmosferik Renk Küreleri (Mesh Gradient Hissi)
          Positioned(top: -100, left: -100, child: _buildAmbientBlob(const Color(0xFF0969DA), 300)),
          Positioned(top: 200, right: -150, child: _buildAmbientBlob(const Color(0xFF8A2BE2), 250)),
          
          // Ana Kaydırılabilir İçerik
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              _buildProgressCard(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              _buildSectionTitle("Hızlı Araçlar", isDark),
              _buildQuickActions(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              _buildSectionTitle("Günün Vakası", isDark),
              _buildInteractiveCaseCard(isDark),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
              _buildSectionTitle("Özel İçerikler", isDark),
              _buildEditorialGrid(isDark),
              const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          ),
        ],
      ),
    );
  }

  // --- 1. ATMOSFER VE APP BAR ---

  Widget _buildAmbientBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _isScrolled ? (isDark ? const Color(0xFF090A0F).withOpacity(0.9) : Colors.white.withOpacity(0.9)) : Colors.transparent,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _isScrolled ? 20 : 0, sigmaY: _isScrolled ? 20 : 0),
          child: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            title: Text(
              "DUS Kampüsü",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                fontSize: 28,
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0, top: 8.0),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            child: IconButton(
              icon: Icon(Icons.bookmark_outline_rounded, color: isDark ? Colors.white : Colors.black87),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
          ),
        )
      ],
    );
  }

  // --- 2. İLHAM VERİCİ PROGRESS KARTI (Glassmorphism) ---

  Widget _buildProgressCard(bool isDark) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _animationController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0969DA).withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 15))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("DUS 2026", style: TextStyle(color: const Color(0xFF0969DA), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
                            const SizedBox(height: 8),
                            Text("Sınava Kalan\nSüre: 142 Gün", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 24, height: 1.2, letterSpacing: -0.5)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xFF0969DA).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Text("Bugün 120 soru çözdün 🔥", style: TextStyle(color: Color(0xFF0969DA), fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ],
                        ),
                      ),
                      // Şık İkonografi
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: const Color(0xFF8A2BE2).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: const Icon(Icons.rocket_rounded, color: Colors.white, size: 40),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. HIZLI ARAÇLAR KAPSÜLLERİ ---

  Widget _buildSectionTitle(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, bottom: 16, right: 24),
        child: Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87, letterSpacing: -0.5),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {"icon": Icons.calculate_rounded, "label": "Puan", "color": const Color(0xFF0969DA)},
      {"icon": Icons.timer_rounded, "label": "Sayaç", "color": const Color(0xFFFF9500)},
      {"icon": Icons.analytics_rounded, "label": "Tercih", "color": const Color(0xFF34C759)},
      {"icon": Icons.calendar_month_rounded, "label": "Takvim", "color": const Color(0xFFAF52DE)},
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
              onTap: () => HapticFeedback.mediumImpact(),
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
                    Text(action["label"] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 4. GÜNÜN VAKASI (3D FLIP KART MEKANİĞİ) ---

  Widget _buildInteractiveCaseCard(bool isDark) {
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.0),
        child: InteractiveCaseWidget(), 
      ),
    );
  }

  // --- 5. EDİTÖRYAL DUS REHBERİ (APPLE APP STORE TARZI HERO KARTLAR) ---

  Widget _buildEditorialGrid(bool isDark) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildEditorialCard(isDark, index);
          },
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildEditorialCard(bool isDark, int index) {
    final images = [
      "https://images.unsplash.com/photo-1606811841689-23dfddce3e95?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=800&q=80",
      "https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=800&q=80"
    ];
    final titles = ["Sınav Kaygısını Yenmenin 5 Bilimsel Yolu", "Etkili Tekrar Stratejileri: Aralıklı Öğrenme", "Derece Yapanların Çalışma Rutinleri"];
    final tags = ["MOTİVASYON", "TAKTİK", "REHBERLİK"];

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        height: 320,
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
          image: DecorationImage(image: NetworkImage(images[index]), fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              stops: const [0.4, 1.0],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Text(tags[index], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(titles[index], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text("4 dk okuma", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// GÜNÜN VAKASI İÇİN ÖZEL INTERAKTİF WIDGET (Oyunlaştırma)
// -----------------------------------------------------------------------------
class InteractiveCaseWidget extends StatefulWidget {
  const InteractiveCaseWidget({super.key});

  @override
  State<InteractiveCaseWidget> createState() => _InteractiveCaseWidgetState();
}

class _InteractiveCaseWidgetState extends State<InteractiveCaseWidget> {
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _isFlipped = !_isFlipped);
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotate = Tween(begin: 3.1415927, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotate,
            child: child,
            builder: (context, widget) {
              final isUnder = (ValueKey(_isFlipped) != widget?.key);
              var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
              tilt *= isUnder ? -1.0 : 1.0;
              final value = isUnder ? min(rotate.value, 3.1415927 / 2) : rotate.value;
              return Transform(
                transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                alignment: Alignment.center,
                child: widget,
              );
            },
          );
        },
        child: _isFlipped ? _buildBackSide(isDark) : _buildFrontSide(isDark),
      ),
    );
  }

  Widget _buildFrontSide(bool isDark) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFFFF9500), size: 24),
              const SizedBox(width: 10),
              Text("Teşhis Et", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "25 yaşında erkek hasta, diş ağrısı şikayetiyle başvuruyor. Ağrı özellikle soğukta artıyor ve uyaran kalkınca hemen geçiyor. Radyografta çürük pulpaya yakın.",
            style: TextStyle(fontSize: 16, height: 1.5, color: isDark ? Colors.white70 : Colors.black87),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text("Çözmek için dokun", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13)),
          )
        ],
      ),
    );
  }

  Widget _buildBackSide(bool isDark) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF34C759).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 32),
          SizedBox(height: 16),
          Text("Reversible Pulpitis", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
          SizedBox(height: 12),
          Text(
            "Tedavi: Çürük temizlenir, kuafaj veya dolgu yapılır. Uyaran ortadan kalkınca ağrı kesildiği için irreversibl aşamaya geçmemiştir.",
            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}