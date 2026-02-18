// lib/widgets/streak_banner.dart
//
// Duolingo tarzı, pill-shaped, yumuşak animasyonlu seri bildirimi.
// Hiçbir overlay veya dialog kullanmaz — saf OverlayEntry yaklaşımı.
// GPU dostu: yalnızca transform + opacity (composite layer tetiklemez).

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../screens/streak_info_sheet.dart';

class StreakBanner {
  /// [streakDays]  → Kaç günlük seri
  /// [isNewDay]    → SADECE true ise banner gösterilir (yeni gün kontrolü)
  /// [isDarkMode]  → Tema
  /// [onDismissed] → Banner kaybolduktan sonra çağrılır
  static Future<void> show({
    required BuildContext context,
    required int streakDays,
    required bool isNewDay,       // 🆕 YENİ PARAMETRE
    required bool isDarkMode,
    VoidCallback? onDismissed,
  }) async {
    // ── Yeni gün değilse veya seri 0 ise hiç gösterme ──
    if (!isNewDay || streakDays <= 0) {
      onDismissed?.call();
      return;
    }

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    final controller = AnimationController(
      vsync: _TickerProviderShim(),
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );

    // Banner tıklandığında sheet açar — entry'den önce tanımla
    void onTap() async {
      // Sheet açıkken banner ekranda kalsın, sheet kapanınca devam etsin
      await StreakInfoSheet.show(
        context: context,
        streakDays: streakDays,
        isDarkMode: isDarkMode,
      );
    }

    entry = OverlayEntry(
      builder: (_) => _StreakBannerWidget(
        streakDays: streakDays,
        isDarkMode: isDarkMode,
        controller: controller,
        onTap: onTap,
      ),
    );

    overlay.insert(entry);
    await controller.forward();

    await Future.delayed(const Duration(milliseconds: 3200));

    await controller.reverse();
    entry.remove();
    controller.dispose();

    onDismissed?.call();
  }
}

// ---------------------------------------------------------------------------
// Banner widget
// ---------------------------------------------------------------------------
class _StreakBannerWidget extends StatelessWidget {
  final int streakDays;
  final bool isDarkMode;
  final AnimationController controller;
  final VoidCallback onTap;

  const _StreakBannerWidget({
    required this.streakDays,
    required this.isDarkMode,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    final fade = CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    final bgColor = isDarkMode ? const Color(0xFF1E2530) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.5)
        : Colors.black.withOpacity(0.12);

    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: GestureDetector(
              onTap: onTap, // 🆕 TAP DESTEĞI
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 0),
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FireIcon(isDarkMode: isDarkMode),
                      const SizedBox(width: 10),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$streakDays',
                              style: const TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF6B35),
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: ' GÜNLÜK SERİ',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: textColor,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tıklanabilir ipucu oku
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: isDarkMode
                            ? Colors.white38
                            : Colors.black26,
                        size: 18,
                      ),
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
}

// ---------------------------------------------------------------------------
// Pulse ateş ikonu
// ---------------------------------------------------------------------------
class _FireIcon extends StatefulWidget {
  final bool isDarkMode;
  const _FireIcon({required this.isDarkMode});

  @override
  State<_FireIcon> createState() => _FireIconState();
}

class _FireIconState extends State<_FireIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Text('🔥', style: TextStyle(fontSize: 26)),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal TickerProvider
// ---------------------------------------------------------------------------
class _TickerProviderShim extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
