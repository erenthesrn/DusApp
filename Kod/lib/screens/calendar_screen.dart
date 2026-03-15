// lib/screens/calendar_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TAKVIM EKRANI
// ─────────────────────────────────────────────────────────────────────────────
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  // Gösterilen ay
  late DateTime _visibleMonth;
  // Seçili gün
  DateTime? _selectedDay;
  // Notlar: 'YYYY-MM-DD' → metin
  Map<String, String> _notes = {};

  // Aralık sınırları
  static final DateTime _minMonth = DateTime(2025, 1);
  static final DateTime _maxMonth = DateTime(2027, 12);

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  static const _accent = Color(0xFFAF52DE); // Takvim moru
  static const _darkBg = Color(0xFF0D1117);
  static const _darkCard = Color(0xFF161B22);
  static const _darkBorder = Color(0xFF30363D);

  static const List<String> _gunBasliklari = [
    'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _loadNotes();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ── Notları SharedPreferences'tan oku ────────────────────────────────────
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('cal_note_'));
    final map = <String, String>{};
    for (final k in keys) {
      final val = prefs.getString(k);
      if (val != null && val.isNotEmpty) {
        map[k.replaceFirst('cal_note_', '')] = val;
      }
    }
    if (mounted) setState(() => _notes = map);
  }

  // ── Notu kaydet / sil ────────────────────────────────────────────────────
  Future<void> _saveNote(String key, String text) async {
    final prefs = await SharedPreferences.getInstance();
    if (text.trim().isEmpty) {
      await prefs.remove('cal_note_$key');
      if (mounted) setState(() => _notes.remove(key));
    } else {
      await prefs.setString('cal_note_$key', text.trim());
      if (mounted) setState(() => _notes[key] = text.trim());
    }
  }

  // ── Tarih anahtarı ────────────────────────────────────────────────────────
  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Ay değiştir ───────────────────────────────────────────────────────────
  void _changeMonth(int delta) {
    HapticFeedback.selectionClick();
    final next =
        DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (next.isBefore(_minMonth) || next.isAfter(_maxMonth)) return;
    _animController.reset();
    setState(() => _visibleMonth = next);
    _animController.forward();
  }

  // ── Ayın günlerini hesapla ────────────────────────────────────────────────
  List<DateTime?> _buildDays() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    // Haftanın ilk günü Pazartesi=1 … Pazar=7
    int startOffset = firstDay.weekday - 1; // 0..6
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;

    final list = <DateTime?>[];
    for (int i = 0; i < startOffset; i++) { list.add(null); }
    for (int d = 1; d <= daysInMonth; d++) {
      list.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    // Satır tamamlama (7'nin katı)
    while (list.length % 7 != 0) { list.add(null); }
    return list;
  }

  // ── Not ekleme / düzenleme alt sayfası ───────────────────────────────────
  void _showNoteSheet(bool isDark) {
    if (_selectedDay == null) return;
    final key = _key(_selectedDay!);
    final existingNote = _notes[key] ?? '';
    final controller = TextEditingController(text: existingNote);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteSheet(
        day: _selectedDay!,
        controller: controller,
        isDark: isDark,
        accent: _accent,
        onSave: (text) {
          _saveNote(key, text);
          Navigator.pop(context);
        },
        onDelete: existingNote.isNotEmpty
            ? () {
                _saveNote(key, '');
                Navigator.pop(context);
              }
            : null,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final days = _buildDays();
    final canPrev = _visibleMonth.isAfter(_minMonth) ||
        _visibleMonth == _minMonth
            ? !(_visibleMonth.year == _minMonth.year &&
                _visibleMonth.month == _minMonth.month)
            : false;
    final canNext = !(_visibleMonth.year == _maxMonth.year &&
        _visibleMonth.month == _maxMonth.month);

    final bgColor = isDark ? _darkBg : const Color(0xFFF3EEFF);
    final cardColor = isDark ? _darkCard : Colors.white;
    final borderColor =
        isDark ? _darkBorder : _accent.withOpacity(0.15);
    final textColor =
        isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final subTextColor =
        isDark ? const Color(0xFF8B949E) : Colors.black45;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Takvim',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? _darkBg : Colors.white).withOpacity(0.55),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Arka plan dekorasyon
          if (isDark) ...[
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.25),
                      blurRadius: 110,
                      spreadRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.2),
                      blurRadius: 80,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withOpacity(0.08),
                ),
              ),
            ),
          ],

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ay Navigasyonu ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(isDark ? 0.08 : 0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _NavBtn(
                            icon: Icons.chevron_left_rounded,
                            enabled: canPrev,
                            isDark: isDark,
                            onTap: () => _changeMonth(-1),
                          ),
                          Column(
                            children: [
                              Text(
                                DateFormat('MMMM', 'tr')
                                    .format(_visibleMonth)
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: _accent,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                '${_visibleMonth.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          _NavBtn(
                            icon: Icons.chevron_right_rounded,
                            enabled: canNext,
                            isDark: isDark,
                            onTap: () => _changeMonth(1),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Takvim Kartı ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withOpacity(isDark ? 0.07 : 0.06),
                            blurRadius: 25,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Gün başlıkları
                          Row(
                            children: _gunBasliklari.map((g) {
                              final isSat = g == 'Cmt';
                              final isSun = g == 'Paz';
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    g,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSun
                                          ? Colors.redAccent
                                          : isSat
                                              ? _accent.withOpacity(0.8)
                                              : subTextColor,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          // Günler grid
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: days.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 2,
                              childAspectRatio: 0.85,
                            ),
                            itemBuilder: (_, i) {
                              final day = days[i];
                              if (day == null) return const SizedBox();

                              final isToday = day.year == today.year &&
                                  day.month == today.month &&
                                  day.day == today.day;
                              final isSelected = _selectedDay != null &&
                                  day.year == _selectedDay!.year &&
                                  day.month == _selectedDay!.month &&
                                  day.day == _selectedDay!.day;
                              final hasNote = _notes.containsKey(_key(day));
                              final isSun = day.weekday == 7;

                              Color dayNumColor;
                              if (isSelected) {
                                dayNumColor = Colors.white;
                              } else if (isToday) {
                                dayNumColor = _accent;
                              } else if (isSun) {
                                dayNumColor = Colors.redAccent;
                              } else {
                                dayNumColor = textColor;
                              }

                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDay = day);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? _accent
                                        : isToday
                                            ? _accent.withOpacity(0.12)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: isToday && !isSelected
                                        ? Border.all(
                                            color: _accent.withOpacity(0.5),
                                            width: 1)
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isToday || isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: dayNumColor,
                                        ),
                                      ),
                                      if (hasNote)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? Colors.white.withOpacity(0.8)
                                                : _accent,
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Seçili Gün Notu ─────────────────────────────────────
                    if (_selectedDay != null) _buildNoteSection(isDark, textColor, subTextColor, cardColor, borderColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection(bool isDark, Color textColor, Color subTextColor,
      Color cardColor, Color borderColor) {
    final key = _key(_selectedDay!);
    final note = _notes[key];
    final dateLabel = DateFormat('d MMMM yyyy, EEEE', 'tr').format(_selectedDay!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.sticky_note_2_rounded,
                  color: _accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    note != null ? 'Not mevcut' : 'Not yok',
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _showNoteSheet(isDark),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      note != null
                          ? Icons.edit_rounded
                          : Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      note != null ? 'Düzenle' : 'Not Ekle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: _accent.withOpacity(0.06),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Text(
              note,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: textColor,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVİGASYON BUTONU
// ─────────────────────────────────────────────────────────────────────────────
class _NavBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBtn({
    required this.icon,
    required this.enabled,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isDark ? const Color(0xFFE6EDF3) : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NOT SAYFASI (BOTTOM SHEET)
// ─────────────────────────────────────────────────────────────────────────────
class _NoteSheet extends StatelessWidget {
  final DateTime day;
  final TextEditingController controller;
  final bool isDark;
  final Color accent;
  final void Function(String) onSave;
  final VoidCallback? onDelete;

  const _NoteSheet({
    required this.day,
    required this.controller,
    required this.isDark,
    required this.accent,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor =
        isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final hintColor =
        isDark ? const Color(0xFF8B949E) : Colors.black38;
    final borderColor = isDark
        ? const Color(0xFF30363D)
        : accent.withOpacity(0.2);
    final dateLabel =
        DateFormat('d MMMM yyyy, EEEE', 'tr').format(day);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tutma çubuğu
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Başlık
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sticky_note_2_rounded,
                      color: accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 20),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Not alanı
            Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: controller,
                maxLines: 5,
                minLines: 3,
                style: TextStyle(fontSize: 14, color: textColor, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'Bugün için bir not yaz...',
                  hintStyle:
                      TextStyle(color: hintColor, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Kaydet butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onSave(controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'Kaydet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
