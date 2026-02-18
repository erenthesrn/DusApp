// lib/widgets/streak_info_sheet.dart — v3
//
// BAĞIMLILIK: just_audio: ^0.9.40
// ASSET:      assets/audio/streak_music.mp3

import 'package:flutter/material.dart';
import 'music_player_widget.dart';

class StreakInfoSheet {
  static Future<void> show({
    required BuildContext context,
    required int streakDays,
    required bool isDarkMode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => _StreakInfoSheetContent(
        streakDays: streakDays,
        isDarkMode: isDarkMode,
      ),
    );
  }
}

class _StreakInfoSheetContent extends StatefulWidget {
  final int streakDays;
  final bool isDarkMode;
  const _StreakInfoSheetContent(
      {required this.streakDays, required this.isDarkMode});

  @override
  State<_StreakInfoSheetContent> createState() =>
      _StreakInfoSheetContentState();
}

class _StreakInfoSheetContentState extends State<_StreakInfoSheetContent>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _pageCount = 4;

  late final AnimationController _entryController;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pageCount - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic);
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    _pageController.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDarkMode ? const Color(0xFF141920) : Colors.white;
    final sheetHeight = MediaQuery.of(context).size.height * 0.82;

    return SlideTransition(
      position: _slideIn,
      child: FadeTransition(
        opacity: _entryController,
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // ── Header: drag handle + müzik ikonu ──
              _SheetHeader(isDarkMode: widget.isDarkMode),

              // ── Sayfa noktaları ──
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PageDots(
                    count: _pageCount,
                    current: _currentPage,
                    isDark: widget.isDarkMode),
              ),

              // ── PageView ──
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _Page1Welcome(
                        streakDays: widget.streakDays,
                        isDark: widget.isDarkMode),
                    _Page2HowItWorks(isDark: widget.isDarkMode),
                    _Page3WhyMatters(isDark: widget.isDarkMode),
                    _Page4Milestones(
                        streakDays: widget.streakDays,
                        isDark: widget.isDarkMode),
                  ],
                ),
              ),

              // ── Nav ──
              _NavBar(
                currentPage: _currentPage,
                pageCount: _pageCount,
                isDark: widget.isDarkMode,
                onNext: _next,
                onPrev: _prev,
                onClose: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — Drag handle ortada, MusicPlayerWidget sağda
// ─────────────────────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final bool isDarkMode;
  const _SheetHeader({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drag handle — merkez
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Müzik widget — sağ
          Positioned(
            right: 0,
            child: MusicPlayerWidget(isDarkMode: isDarkMode),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SAYFA 1
// ===========================================================================
class _Page1Welcome extends StatefulWidget {
  final int streakDays;
  final bool isDark;
  const _Page1Welcome({required this.streakDays, required this.isDark});

  @override
  State<_Page1Welcome> createState() => _Page1WelcomeState();
}

class _Page1WelcomeState extends State<_Page1Welcome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fire;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _fire = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _fire, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _fire.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleColor =
        widget.isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor =
        widget.isDark ? Colors.white60 : const Color(0xFF64748B);

    String headline;
    String subtitle;
    if (widget.streakDays == 1) {
      headline = 'Seriye Başladın!';
      subtitle = 'DUS yolculuğunun ilk adımını attın. Her gün biraz daha ileri!';
    } else if (widget.streakDays < 7) {
      headline = 'Harika Gidiyorsun!';
      subtitle =
          '${widget.streakDays} gündür aralıksız çalışıyorsun. Bu ivmeyi koru!';
    } else if (widget.streakDays < 30) {
      headline = 'Gerçek Bir Azim!';
      subtitle =
          '${widget.streakDays} günlük seri ciddi bir kararlılığın göstergesi!';
    } else {
      headline = 'Efsane Seviyesi!';
      subtitle = '${widget.streakDays} gün! Bu noktaya gelmek gerçek bir başarı.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFFF6B35).withOpacity(0.25),
                      Colors.transparent
                    ]),
                  ),
                ),
                const Text('🔥', style: TextStyle(fontSize: 80)),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B35),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFFFF6B35).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ],
                    ),
                    child: Text(
                      '${widget.streakDays}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  height: 1.1)),
          const SizedBox(height: 14),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 16, color: subColor, height: 1.5)),
        ],
      ),
    );
  }
}

// ===========================================================================
// SAYFA 2
// ===========================================================================
class _Page2HowItWorks extends StatelessWidget {
  final bool isDark;
  const _Page2HowItWorks({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final cardBg =
        isDark ? const Color(0xFF1E2530) : const Color(0xFFF8FAFF);

    final steps = [
      ('📅', 'Her Gün Çalış',
          'Her gün en az bir test çözdüğünde serin bir gün artar.'),
      ('⚡', 'Zinciri Kırma',
          'Bir gün atlarsanız seri sıfırlanır. Ertesi gün yeniden başlar.'),
      ('🌙', 'Gece Yarısı Sıfırı',
          "Gün sayımı gece 00:00'da sıfırlanır. Güne yetişin!"),
      ('🏆', 'Rozet Kazan',
          'Belirli seri uzunluklarında özel rozetler açılır.'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Seri Nasıl Çalışır?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: titleColor)),
          const SizedBox(height: 20),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.$2,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: titleColor)),
                            const SizedBox(height: 4),
                            Text(s.$3,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ===========================================================================
// SAYFA 3
// ===========================================================================
class _Page3WhyMatters extends StatelessWidget {
  final bool isDark;
  const _Page3WhyMatters({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final subColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final stats = [
      ('📈', '21 gün', 'Bir alışkanlık oluşması için gereken minimum süre'),
      ('🧠', '5×', 'Düzenli tekrar, bilgiyi 5 kat daha kalıcı yapar'),
      ("🎯", '%73', "DUS'u kazananların düzenli çalışma oranı"),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neden Önemli?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: titleColor)),
          const SizedBox(height: 8),
          Text(
              'Aralıklı tekrar, tıp eğitiminde en kanıtlanmış öğrenme yöntemidir.',
              style: TextStyle(fontSize: 14, color: subColor, height: 1.5)),
          const SizedBox(height: 24),
          ...stats.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2530)
                        : const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04)),
                  ),
                  child: Row(
                    children: [
                      Text(s.$1, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.$2,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFFF6B35))),
                          Text(s.$3,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"Her gün az ama düzenli, yoğun ama düzensizden çok daha etkilidir."',
                    style: TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SAYFA 4
// ===========================================================================
class _Page4Milestones extends StatelessWidget {
  final int streakDays;
  final bool isDark;
  const _Page4Milestones({required this.streakDays, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final milestones = [
      (1, '🌱', 'Tohum', 'Başlangıç'),
      (7, '🔥', 'Ateş', '1 Hafta'),
      (21, '⚡', 'Alışkanlık', '3 Hafta'),
      (30, '🌟', 'Yıldız', '1 Ay'),
      (60, '💎', 'Kristal', '2 Ay'),
      (100, '👑', 'Kral', '100 Gün'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kilometre Taşları',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: titleColor)),
          const SizedBox(height: 6),
          Text('Şu anki seriniz: $streakDays gün',
              style: const TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: milestones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final m = milestones[i];
                final isReached = streakDays >= m.$1;
                final isCurrent = !isReached &&
                    (i == 0 || streakDays >= milestones[i - 1].$1);

                Color borderColor;
                Color bgColor;
                Color textColor;

                if (isReached) {
                  borderColor = const Color(0xFFFF6B35);
                  bgColor = isDark
                      ? const Color(0xFFFF6B35).withOpacity(0.12)
                      : const Color(0xFFFFF3EE);
                  textColor = const Color(0xFFFF6B35);
                } else if (isCurrent) {
                  borderColor = Colors.blue.shade400;
                  bgColor = isDark
                      ? Colors.blue.withOpacity(0.1)
                      : const Color(0xFFEFF6FF);
                  textColor = Colors.blue.shade400;
                } else {
                  borderColor = isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.06);
                  bgColor = isDark
                      ? const Color(0xFF1E2530)
                      : const Color(0xFFF8FAFF);
                  textColor =
                      isDark ? Colors.white38 : Colors.black38;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: borderColor,
                        width: isReached ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(isReached || isCurrent ? m.$2 : '🔒',
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(m.$3,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isReached
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(
                                                    0xFF1A1A2E))
                                            : textColor)),
                                Text(m.$4,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: textColor)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${m.$1} gün',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor)),
                          ),
                          if (isReached) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle,
                                color: Color(0xFFFF6B35), size: 20),
                          ],
                        ],
                      ),
                      if (isCurrent) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: streakDays / m.$1,
                            backgroundColor: isDark
                                ? Colors.white12
                                : Colors.blue.withOpacity(0.15),
                            color: Colors.blue.shade400,
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text('$streakDays / ${m.$1} gün',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade400,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// YARDIMCI
// ===========================================================================

class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final bool isDark;
  const _PageDots(
      {required this.count, required this.current, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFF6B35)
                : (isDark ? Colors.white24 : Colors.black12),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final bool isDark;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onClose;

  const _NavBar({
    required this.currentPage,
    required this.pageCount,
    required this.isDark,
    required this.onNext,
    required this.onPrev,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == pageCount - 1;
    final textColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          if (currentPage > 0)
            TextButton(
                onPressed: onPrev,
                child: Text('Geri',
                    style: TextStyle(color: textColor, fontSize: 15)))
          else
            const SizedBox(width: 60),
          const Spacer(),
          GestureDetector(
            onTap: isLast ? onClose : onNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                  horizontal: isLast ? 32 : 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)]),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF6B35).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLast ? 'Harika!' : 'İleri',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  if (!isLast) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ] else ...[
                    const SizedBox(width: 6),
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
