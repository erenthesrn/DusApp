// lib/widgets/music_player_widget.dart
//
// Streak Info Sheet'in sağ üst köşesinde duran müzik ikonu + animasyonlu barlar.
// Tıklandığında assets/audio/streak_music.mp3 dosyasını 6-7 saniye çalar.
//
// BAĞIMLILIK (pubspec.yaml'a ekleyin):
//   just_audio: ^0.9.40
//
// ASSET (pubspec.yaml'a ekleyin):
//   flutter:
//     assets:
//       - assets/audio/streak_music.mp3

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MusicPlayerWidget extends StatefulWidget {
  final bool isDarkMode;

  const MusicPlayerWidget({super.key, required this.isDarkMode});

  @override
  State<MusicPlayerWidget> createState() => _MusicPlayerWidgetState();
}

class _MusicPlayerWidgetState extends State<MusicPlayerWidget>
    with TickerProviderStateMixin {
  // ── Audio ──────────────────────────────────────────────────────────────
  late final AudioPlayer _player;
  bool _isPlaying = false;

  // ── Bar animasyonları (4 bar, her biri bağımsız hız) ──────────────────
  static const int _barCount = 4;
  late final List<AnimationController> _barControllers;
  late final List<Animation<double>> _barAnimations;

  // Bar yükseklik oranları (0.0 → 1.0)
  static const List<double> _barSpeeds = [0.55, 0.75, 0.45, 0.65];
  static const double _maxBarHeight = 18.0;
  static const double _minBarHeight = 3.0;

  // ── Otomatik durdurma ──────────────────────────────────────────────────
  static const Duration _playDuration = Duration(seconds: 7);

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    _player.setAsset('assets/audio/streak_music.mp3').catchError((e) {
      debugPrint('🎵 Müzik asset yüklenemedi: $e');
    });

    // Her bar için farklı hızda salınım animasyonu
    _barControllers = List.generate(_barCount, (i) {
      final speed = _barSpeeds[i];
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (400 / speed).round()),
      );
    });

    _barAnimations = _barControllers.map((c) {
      return Tween<double>(begin: _minBarHeight, end: _maxBarHeight).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _barControllers) {
      c.dispose();
    }
    _player.dispose();
    super.dispose();
  }

  // ── Oynat / Durdur ─────────────────────────────────────────────────────
  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _stopMusic();
    } else {
      await _startMusic();
    }
  }

  Future<void> _startMusic() async {
    try {
      setState(() => _isPlaying = true);

      // Bar animasyonlarını başlat
      for (final c in _barControllers) {
        c.repeat(reverse: true);
      }

      await _player.seek(Duration.zero);
      await _player.play();

      // 7 saniye sonra otomatik durdur
      Future.delayed(_playDuration, () {
        if (mounted && _isPlaying) _stopMusic();
      });
    } catch (e) {
      debugPrint('🎵 Oynatma hatası: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _stopMusic() async {
    await _player.stop();
    for (final c in _barControllers) {
      c.animateTo(0, duration: const Duration(milliseconds: 200));
    }
    await Future.delayed(const Duration(milliseconds: 220));
    if (mounted) {
      setState(() => _isPlaying = false);
      for (final c in _barControllers) {
        c.reset();
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final iconColor = _isPlaying
        ? const Color(0xFFFF6B35)
        : (widget.isDarkMode ? Colors.white38 : Colors.black26);

    final bgColor = _isPlaying
        ? const Color(0xFFFF6B35).withOpacity(0.12)
        : (widget.isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04));

    final borderColor = _isPlaying
        ? const Color(0xFFFF6B35).withOpacity(0.35)
        : (widget.isDarkMode
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.06));

    return GestureDetector(
      onTap: _togglePlay,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _isPlaying
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Müzik notası ikonu ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isPlaying
                    ? Icons.music_note_rounded
                    : Icons.music_note_outlined,
                key: ValueKey(_isPlaying),
                color: iconColor,
                size: 22,
              ),
            ),

            const SizedBox(height: 6),

            // ── Animasyonlu barlar ──
            SizedBox(
              height: _maxBarHeight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(_barCount, (i) {
                  return Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                    child: _isPlaying
                        ? AnimatedBuilder(
                            animation: _barAnimations[i],
                            builder: (_, __) => _Bar(
                              height: _barAnimations[i].value,
                              color: const Color(0xFFFF6B35),
                              isDark: widget.isDarkMode,
                            ),
                          )
                        : _Bar(
                            height: _minBarHeight,
                            color: iconColor,
                            isDark: widget.isDarkMode,
                          ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tek bir bar
// ---------------------------------------------------------------------------
class _Bar extends StatelessWidget {
  final double height;
  final Color color;
  final bool isDark;

  const _Bar({
    required this.height,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      width: 3.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
