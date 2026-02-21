// lib/widgets/streak_banner.dart
//
// Duolingo tarzı, pill-shaped, yumuşak animasyonlu seri bildirimi.
// Hiçbir overlay veya dialog kullanmaz — saf OverlayEntry yaklaşımı.
// GPU dostu: yalnızca transform + opacity (composite layer tetiklemez).

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'streak_info_sheet.dart';

class StreakBanner {
  /// [streakDays]  → Kaç günlük seri
  /// [isNewDay]    → SADECE true ise banner gösterilir (yeni gün kontrolü)
  /// [isDarkMode]  → Tema
  /// [onDismissed] → Banner kaybolduktan sonra çağrılır
  static Future<void> show({
    required BuildContext context,
    required int streakDays,
    required bool isNewDay,
    required bool isDarkMode,
    VoidCallback? onDismissed,
  }) async {
    if (!isNewDay || streakDays <= 0) {
      onDismissed?.call();
      return;
    }

    final completer = Completer<void>();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _StreakBannerWidget(
        streakDays: streakDays,
        isDarkMode: isDarkMode,
        onDismiss: () {
          entry.remove();
          onDismissed?.call();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    overlay.insert(entry);
    return completer.future; // Banner tamamen kapanana kadar bekle
  }
}

// ---------------------------------------------------------------------------
// Banner widget (Artık StatefulWidget ve kendi zamanlayıcısını yönetiyor)
// ---------------------------------------------------------------------------
class _StreakBannerWidget extends StatefulWidget {
  final int streakDays;
  final bool isDarkMode;
  final VoidCallback onDismiss;

  const _StreakBannerWidget({
    required this.streakDays,
    required this.isDarkMode,
    required this.onDismiss,
  });

  @override
  State<_StreakBannerWidget> createState() => _StreakBannerWidgetState();
}

class _StreakBannerWidgetState extends State<_StreakBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _closeTimer;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );

    _controller.forward();
    // 1. Durum: Hiçbir şeye tıklanmazsa varsayılan olarak 5 saniye içinde kapanır
    _startCloseTimer(const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCloseTimer(Duration duration) {
    _closeTimer?.cancel();
    _closeTimer = Timer(duration, _closeBanner);
  }

  Future<void> _closeBanner() async {
    if (_isClosing) return;
    _isClosing = true;
    _closeTimer?.cancel();
    await _controller.reverse();
    widget.onDismiss();
  }

  void _onMusicToggled(bool isPlaying) {
    if (isPlaying) {
      // 2. Durum: Müzik çalmaya başladı, banner süresini 10 saniyeye uzat
      _startCloseTimer(const Duration(seconds: 10));
    } else {
      // 3. Durum: Müzik ikonuna tekrar basılarak durduruldu, banner'ı hemen kapat
      _closeBanner();
    }
  }

  Future<void> _onTap() async {
    await StreakInfoSheet.show(
      context: context,
      streakDays: widget.streakDays,
      isDarkMode: widget.isDarkMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    final fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    final bgColor = widget.isDarkMode ? const Color(0xFF1E2530) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
    final shadowColor = widget.isDarkMode
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
              onTap: _onTap,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
                        color: widget.isDarkMode
                            ? Colors.white.withOpacity(0.06)
                            : Colors.white.withOpacity(0.9),
                        blurRadius: 0,
                        offset: const Offset(0, 0),
                        spreadRadius: 1,
                      ),
                    ],
                    border: Border.all(
                      color: widget.isDarkMode
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.04),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FireIcon(isDarkMode: widget.isDarkMode),
                      const SizedBox(width: 10),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${widget.streakDays}',
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
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: widget.isDarkMode ? Colors.white38 : Colors.black26,
                        size: 18,
                      ),
                      // ── Dikey ayraç ──────────────────────────────────────
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: widget.isDarkMode
                            ? Colors.white.withOpacity(0.12)
                            : Colors.black.withOpacity(0.08),
                      ),
                      // ── Müzik butonu ─────────────────────────────────────
                      _MusicButton(
                        isDarkMode: widget.isDarkMode,
                        onToggled: _onMusicToggled,
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
// 🎵 Müzik butonu
// ---------------------------------------------------------------------------
class _MusicButton extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggled; // Parent'a durum bildirmek için eklendi

  const _MusicButton({
    required this.isDarkMode,
    required this.onToggled,
  });

  @override
  State<_MusicButton> createState() => _MusicButtonState();
}

class _MusicButtonState extends State<_MusicButton>
    with TickerProviderStateMixin {
  late final List<AnimationController> _barControllers;
  late final List<Animation<double>> _barAnimations;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Timer? _stopTimer;

  static const int _barCount = 4;
  final List<double> _speedFactors = [1.0, 0.75, 1.3, 0.9];
  final List<double> _minHeights = [0.25, 0.35, 0.20, 0.40];

  @override
  void initState() {
    super.initState();

    _barControllers = List.generate(_barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (500 * _speedFactors[i]).round()),
      )..repeat(reverse: true);
    });

    _barAnimations = List.generate(_barCount, (i) {
      return Tween<double>(begin: _minHeights[i], end: 1.0).animate(
        CurvedAnimation(
          parent: _barControllers[i],
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _barControllers) {
      c.dispose();
    }
    _stopTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isPlaying) {
      // Eğer halihazırda çalıyorsa müziği durdur ve parent'a (banner'a) false gönder
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
      _stopTimer?.cancel();
      widget.onToggled(false); 
      return;
    }

    setState(() => _isPlaying = true);
    widget.onToggled(true);

    await _player.play(AssetSource('audio/streak_music.mp3'));

    // 10 saniye sonra müziği kendiliğinden durdur
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(seconds: 10), () async {
      await _player.stop();
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _isPlaying ? const Color(0xFF4ECDC4) : const Color(0xFFFF6B35);
    final mutedColor = widget.isDarkMode ? Colors.white38 : Colors.black26;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              _isPlaying ? Icons.music_note_rounded : Icons.music_note_outlined,
              key: ValueKey(_isPlaying),
              color: _isPlaying ? accentColor : mutedColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 22,
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_barCount, (i) {
                return AnimatedBuilder(
                  animation: _barAnimations[i],
                  builder: (_, __) {
                    final heightFraction = _isPlaying ? _barAnimations[i].value : _minHeights[i];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 3,
                      height: 14 * heightFraction,
                      decoration: BoxDecoration(
                        color: _isPlaying ? accentColor : mutedColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
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