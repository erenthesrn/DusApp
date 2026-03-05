// lib/screens/guest_home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/question_model.dart';
import 'login_page.dart';
import 'quiz_screen.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _cardsController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  List<Map<String, dynamic>> _tests = [];
  bool _isLoadingTests = true;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _cardsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardsController.forward();
    });

    _loadGuestTests();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  Future<void> _loadGuestTests() async {
    try {
      // Assets'ten yükle — ileride assets/guest.json olarak ekleyebilirsiniz
      // Şimdilik hard-coded JSON kullanıyoruz (guest.json hazır olunca değiştirin)
      final String jsonStr = await rootBundle.loadString('assets/guest.json');
      final Map<String, dynamic> data = json.decode(jsonStr);
      if (mounted) {
        setState(() {
          _tests = List<Map<String, dynamic>>.from(data['tests']);
          _isLoadingTests = false;
        });
      }
    } catch (e) {
      // Fallback: JSON yüklenemezse boş liste göster
      debugPrint('guest.json yüklenemedi: $e');
      if (mounted) {
        setState(() => _isLoadingTests = false);
      }
    }
  }

  void _goToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _startDemoTest(Map<String, dynamic> testData) {
    final List<dynamic> rawQuestions = testData['questions'] as List<dynamic>;
    final List<Question> questions = rawQuestions.map((q) {
      final map = q as Map<String, dynamic>;
      return Question(
        id: map['questionIndex'] ?? map['id'] ?? 0,
        question: map['question'] ?? '',
        options: List<String>.from(map['options'] ?? []),
        answerIndex: map['answerIndex'] ?? map['correctIndex'] ?? 0,
        explanation: map['explanation'] ?? '',
        testNo: map['testNo'] ?? 1,
        level: map['topic'] ?? 'Demo',
        imageUrl: map['image_url'],
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          isTrial: false,
          topic: testData['title'] as String?,
          testNo: testData['testNo'] as int? ?? 1,
          questions: questions,
        ),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: Colors.amber, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Üyelere Özel',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tüm derslere erişmek ve ilerlemeni kaydetmek için ücretsiz üye ol.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _goToLogin();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Ücretsiz Kayıt Ol',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Daha Sonra',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        _goToLogin();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _buildSectionHeader(
                      'Demo Testler',
                      '15 dakika • 10 soru',
                      Icons.bolt_rounded,
                      Colors.amber,
                    ),
                    const SizedBox(height: 16),
                    _buildDemoTestsList(),
                    const SizedBox(height: 36),
                    _buildSectionHeader(
                      'Kilitli İçerikler',
                      'Üye ol, tümünü aç',
                      Icons.lock_rounded,
                      Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    _buildLockedSubjectsList(),
                    const SizedBox(height: 32),
                    _buildRegisterBanner(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: const Color(0xFF0D1B6E),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
        onPressed: _goToLogin,
      ),
      actions: [
        TextButton(
          onPressed: _goToLogin,
          child: const Text(
            'Giriş Yap',
            style: TextStyle(
              color: Colors.amber,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: _buildHeroSection(),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B6E), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Dekoratif arka plan daireler
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withOpacity(0.08),
              ),
            ),
          ),
          // İçerik
          SafeArea(
            child: FadeTransition(
              opacity: _heroFade,
              child: SlideTransition(
                position: _heroSlide,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.4), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome,
                                color: Colors.amber, size: 11),
                            SizedBox(width: 4),
                            Text(
                              'DUS Asistanı • Demo',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Türkiye\'nin En Akıllı\nDUS Platformu',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ücretsiz 3 demo testi çöz, farkı hemen hisset.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildHeroStats(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Row(
      children: [
        _buildStatChip('10K+', 'Soru'),
        const SizedBox(width: 12),
        _buildStatChip('500+', 'Test'),
        const SizedBox(width: 12),
        _buildStatChip('%94', 'Başarı'),
      ],
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B6E),
                letterSpacing: -0.3,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemoTestsList() {
    if (_isLoadingTests) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF1565C0)),
        ),
      );
    }

    if (_tests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'Demo testler yüklenemedi. Lütfen assets/guest.json dosyasını kontrol edin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: List.generate(_tests.length, (index) {
        return AnimatedBuilder(
          animation: _cardsController,
          builder: (context, child) {
            final delay = index * 0.15;
            final progress = (_cardsController.value - delay).clamp(0.0, 1.0) /
                (1.0 - delay).clamp(0.01, 1.0);
            return Transform.translate(
              offset: Offset(0, 24 * (1 - progress)),
              child: Opacity(
                opacity: progress.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DemoTestCard(
              testData: _tests[index],
              index: index,
              onTap: () => _startDemoTest(_tests[index]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLockedSubjectsList() {
    const subjects = [
      {'title': 'Farmakoloji', 'icon': Icons.medication_rounded, 'count': '48 Test'},
      {'title': 'Patoloji', 'icon': Icons.biotech_rounded, 'count': '36 Test'},
      {'title': 'Mikrobiyoloji', 'icon': Icons.coronavirus_rounded, 'count': '42 Test'},
      {'title': 'Histoloji', 'icon': Icons.grid_4x4_rounded, 'count': '28 Test'},
      {'title': 'Cerrahi', 'icon': Icons.medical_services_rounded, 'count': '55 Test'},
      {'title': 'Ve daha fazlası...', 'icon': Icons.more_horiz_rounded, 'count': '500+ Test'},
    ];

    return Column(
      children: subjects.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _LockedSubjectTile(
            title: s['title'] as String,
            icon: s['icon'] as IconData,
            count: s['count'] as String,
            onTap: _showLoginRequiredDialog,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRegisterBanner() {
    return GestureDetector(
      onTap: _goToLogin,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1B6E), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tüm İçerikleri\nÜcretsiz Aç 🎓',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '10.000+ soru, detaylı analizler ve daha fazlası.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Hemen Kaydol →',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const Text('🚀', style: TextStyle(fontSize: 56)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Demo Test Kartı
// ─────────────────────────────────────────────────────────────────────────

class _DemoTestCard extends StatefulWidget {
  final Map<String, dynamic> testData;
  final int index;
  final VoidCallback onTap;

  const _DemoTestCard({
    required this.testData,
    required this.index,
    required this.onTap,
  });

  @override
  State<_DemoTestCard> createState() => _DemoTestCardState();
}

class _DemoTestCardState extends State<_DemoTestCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  static const List<List<Color>> _gradients = [
    [Color(0xFFE53935), Color(0xFFB71C1C)],
    [Color(0xFF1E88E5), Color(0xFF0D47A1)],
    [Color(0xFF43A047), Color(0xFF1B5E20)],
  ];

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  List<Color> get _gradient =>
      _gradients[widget.index % _gradients.length];

  Color get _accentColor => _gradient[0];

  @override
  Widget build(BuildContext context) {
    final int questionCount =
        (widget.testData['questions'] as List?)?.length ?? 0;

    return GestureDetector(
      onTapDown: (_) => _pressController.reverse(),
      onTapUp: (_) {
        _pressController.forward();
        widget.onTap();
      },
      onTapCancel: () => _pressController.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // İkon alanı
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.quiz_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Başlık ve bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.testData['title'] as String? ?? 'Demo Test',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D1B6E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.testData['subtitle'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildBadge(
                          Icons.help_outline_rounded,
                          '$questionCount Soru',
                          _accentColor.withOpacity(0.1),
                          _accentColor,
                        ),
                        const SizedBox(width: 8),
                        _buildBadge(
                          Icons.timer_outlined,
                          'Süresiz',
                          Colors.orange.withOpacity(0.1),
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Başlat butonu
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _accentColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(
      IconData icon, String label, Color bg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Kilitli ders satırı
// ─────────────────────────────────────────────────────────────────────────

class _LockedSubjectTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final String count;
  final VoidCallback onTap;

  const _LockedSubjectTile({
    required this.title,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.grey[400], size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                    ),
                  ),
                  Text(
                    count,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.lock_rounded, color: Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }
}
