// lib/screens/exam_setup_screen.dart
//
// DUS Sınav Provası kurulum ekranı.
// Akış: Kategori → (Ders Seçimi) → Soru Sayısı → Onay → QuizScreen
//
// Düzeltmeler:
//   1. Soru listesi Firestore'dan dinamik çekilir — yeni soru ekleyince otomatik dahil
//   2. Temel / Klinik seçince ders bazlı filtreleme yapılabilir (veya "Tümü")
//   3. Sınav Provası sonuçları yanlışlar listesine AYRI kaydedilir (source: 'prova')
//      → Anatomi Test-1 yanlışlarını etkilemez, prova yanlışları bağımsızdır
//
// quiz_screen.dart'ta GEREKLİ TEK DEĞİŞİKLİK:
//   _calculateResults içindeki isMistakeReview satırını şununla değiştir:
//
//   bool isMistakeReview = widget.questions != null &&
//                          !widget.isReviewMode &&
//                          (widget.topic?.contains('Tekrar') ?? false);
//
//   Bu sayede Prova topic'i "Tekrar" içermediği için yanlışlar listesine
//   dokunmaz — tamamen bağımsız çalışır.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/question_model.dart';
import 'quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sabitler — YENİ DERS EKLEYİNCE SADECE BU HARİTALARA EKLE
// ─────────────────────────────────────────────────────────────────────────────

enum _ExamCategory { temel, klinik, karisik }

/// Firestore 'topic' değeri → görünen ders adı
/// Yeni ders ekleyince buraya bir satır eklemen yeterli.
/// Firestore'daki dokümanın 'topic' alanı da aynı key'i kullanmalı.
const Map<String, String> kTemelTopics = {
  'anatomi': 'Anatomi',
  'biyokimya': 'Biyokimya',
  'biyoloji': 'Biyoloji ve Genetik',
  'farma': 'Farmakoloji',
  'fizyoloji': 'Fizyoloji',
  'histoloji': 'Histoloji ve Embriyoloji',
  'mikrobiyo': 'Mikrobiyoloji',
  'patoloji': 'Patoloji',
};

const Map<String, String> kKlinikTopics = {
  'cerrahi': 'Ağız, Diş ve Çene Cerrahisi',
  'radyoloji': 'Ağız, Diş ve Çene Radyolojisi',
  'endo': 'Endodonti',
  'orto': 'Ortodonti',
  'pedo': 'Pedodonti',
  'perio': 'Periodontoloji',
  'protetik': 'Protetik Diş Tedavisi',
  'resto': 'Restoratif Diş Tedavisi',
};

const _questionCounts = [10, 20, 30];

// ─────────────────────────────────────────────────────────────────────────────
// ExamSetupScreen
// ─────────────────────────────────────────────────────────────────────────────

class ExamSetupScreen extends StatefulWidget {
  const ExamSetupScreen({super.key});

  @override
  State<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends State<ExamSetupScreen> {
  _ExamCategory? _selectedCategory;

  /// null = "Tüm Dersler", dolu = belirli bir topic key'i ('anatomi' gibi)
  String? _selectedTopicKey;

  int? _selectedCount;
  bool _isLoading = false;

  // ── Yardımcılar ────────────────────────────────────────────────────────────

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _titleColor =>
      _isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);

  Color get _subtitleColor =>
      _isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400;

  Color get _cardBg => _isDark
      ? const Color(0xFF161B22).withOpacity(0.6)
      : Colors.white.withOpacity(0.85);

  Color get _borderColor =>
      _isDark ? Colors.white.withOpacity(0.08) : Colors.white;

  bool get _canProceed =>
      _selectedCategory != null && _selectedCount != null;

  Map<String, String> get _currentTopicMap {
    if (_selectedCategory == _ExamCategory.temel) return kTemelTopics;
    if (_selectedCategory == _ExamCategory.klinik) return kKlinikTopics;
    return {};
  }

  String get _selectedTopicLabel {
    if (_selectedTopicKey == null) return 'Tüm Dersler';
    return _currentTopicMap[_selectedTopicKey] ?? _selectedTopicKey!;
  }

  // ── Kategori değişince ders seçimini sıfırla ───────────────────────────────
  void _onCategorySelected(_ExamCategory cat) {
    setState(() {
      _selectedCategory = cat;
      _selectedTopicKey = null;
    });
  }

  // ── Firestore Fetch ────────────────────────────────────────────────────────
  // Dinamik: kTemelTopics / kKlinikTopics haritasından topic listesi alınır.
  // Yeni ders eklenince haritaya eklemek yeterli — başka kod değişikliği gerekmez.

  Future<List<Question>> _fetchQuestions() async {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('questions');

    if (_selectedCategory == _ExamCategory.karisik) {
      // Tüm sorular — shuffle + take ile rastgele N tane alınacak
      query = query.limit(800);
    } else if (_selectedTopicKey != null) {
      // Belirli bir ders
      query = query.where('topic', isEqualTo: _selectedTopicKey);
    } else {
      // Kategorinin tüm dersleri (whereIn — Firestore max 30 eleman destekler)
      final topics = _currentTopicMap.keys.toList();
      query = query.where('topic', whereIn: topics);
    }

    final snapshot = await query.get();

    return snapshot.docs.map((doc) {
      final d = doc.data();
      return Question(
        id: (d['questionIndex'] ?? 0) as int,
        question: d['question'] ?? '',
        options: List<String>.from(d['options'] ?? []),
        answerIndex: (d['correctIndex'] ?? 0) as int,
        explanation: d['explanation'] ?? '',
        testNo: (d['testNo'] ?? 0) as int,
        level: d['topic'] ?? 'Genel',
        imageUrl: d['image_url'],
      );
    }).toList();
  }

  // ── Onay ve Başlatma ────────────────────────────────────────────────────────

  Future<void> _confirmAndStart() async {
    if (!_canProceed) return;

    final categoryLabel = _selectedCategory == _ExamCategory.temel
        ? 'Temel Bilimler'
        : _selectedCategory == _ExamCategory.klinik
            ? 'Klinik Bilimler'
            : 'Karışık';

    final confirmed = await _showConfirmSheet(
      categoryLabel: categoryLabel,
      topicLabel: _selectedTopicLabel,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final all = await _fetchQuestions();

      if (all.isEmpty) {
        _showError('Bu seçimde henüz soru bulunamadı.');
        return;
      }

      // Her çağrıda farklı shuffle — yeni sorular otomatik dahil olur
      all.shuffle();
      final picked = all.take(_selectedCount!).toList();

      if (!mounted) return;

      // FIX 3: topic adı "Prova" içeriyor ama "Tekrar" içermiyor.
      // quiz_screen.dart'taki isMistakeReview kontrolü 'Tekrar' arar,
      // bu yüzden prova sonuçları eski yanlışları etkilemez.
      // Aynı soru hem anatomi yanlışlarında hem prova yanlışlarında
      // bağımsız şekilde var olabilir.
      // Yanlışlar ekranında hepsi aynı başlık altında görünsün
      const provaTopicName = 'Sınav Provası';

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            isTrial: true,
            questions: picked,
            topic: provaTopicName,
            // testNo verilmiyor → varsayılan 0, normal test ID'leriyle çakışmaz
          ),
        ),
      );
    } catch (e) {
      debugPrint('ExamSetupScreen fetch error: $e');
      _showError('Sorular yüklenirken hata oluştu. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmSheet({
    required String categoryLabel,
    required String topicLabel,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        categoryLabel: categoryLabel,
        topicLabel: topicLabel,
        questionCount: _selectedCount!,
        isDark: _isDark,
      ),
    );
    return result ?? false;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Ders Seçim Sheet ────────────────────────────────────────────────────────

  void _showTopicPicker() async {
    if (_currentTopicMap.isEmpty) return;

    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TopicPickerSheet(
        topicMap: _currentTopicMap,
        selectedKey: _selectedTopicKey,
        isDark: _isDark,
      ),
    );

    // '' (boş string) = "Tüm Dersler" seçildi
    // null = sheet kapatıldı, değişiklik yok
    // 'anatomi' gibi = ders seçildi
    if (result != null) {
      setState(() {
        _selectedTopicKey = result.isEmpty ? null : result;
      });
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          _isDark ? const Color(0xFF0A0E14) : const Color(0xFFE0F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color:
                  _isDark ? Colors.white70 : Colors.blueGrey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sınav Provası',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: _titleColor,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Bir sınav ortamı oluşturalım.\nKategori ve soru sayısını seç.',
                style: GoogleFonts.inter(
                    fontSize: 15, color: _subtitleColor),
              ),
              const SizedBox(height: 32),

              // ── ADIM 1: Kategori ───────────────────────────────────────
              _SectionLabel(label: '1. Kategori Seç', isDark: _isDark),
              const SizedBox(height: 14),

              _CategoryTile(
                label: 'Temel Bilimler',
                icon: Icons.biotech_outlined,
                color: Colors.orange,
                isSelected: _selectedCategory == _ExamCategory.temel,
                isDark: _isDark,
                cardBg: _cardBg,
                borderColor: _borderColor,
                onTap: () => _onCategorySelected(_ExamCategory.temel),
              ),
              _CategoryTile(
                label: 'Klinik Bilimler',
                icon: Icons.health_and_safety_outlined,
                color: Colors.blue,
                isSelected:
                    _selectedCategory == _ExamCategory.klinik,
                isDark: _isDark,
                cardBg: _cardBg,
                borderColor: _borderColor,
                onTap: () =>
                    _onCategorySelected(_ExamCategory.klinik),
              ),
              _CategoryTile(
                label: 'Karışık (Tüm Dersler)',
                icon: Icons.shuffle_rounded,
                color: const Color(0xFF673AB7),
                isSelected:
                    _selectedCategory == _ExamCategory.karisik,
                isDark: _isDark,
                cardBg: _cardBg,
                borderColor: _borderColor,
                onTap: () =>
                    _onCategorySelected(_ExamCategory.karisik),
              ),

              // ── ADIM 2: Ders Seçimi (Karışık'ta görünmez) ─────────────
              if (_selectedCategory != null &&
                  _selectedCategory != _ExamCategory.karisik) ...[
                const SizedBox(height: 32),
                _SectionLabel(
                    label: '2. Ders Seç (İsteğe Bağlı)',
                    isDark: _isDark),
                const SizedBox(height: 14),
                _TopicSelectorButton(
                  label: _selectedTopicLabel,
                  isDark: _isDark,
                  cardBg: _cardBg,
                  borderColor: _borderColor,
                  color: _selectedCategory == _ExamCategory.temel
                      ? Colors.orange
                      : Colors.blue,
                  onTap: _showTopicPicker,
                ),
              ],

              // ── ADIM 3: Soru Sayısı ────────────────────────────────────
              const SizedBox(height: 32),
              _SectionLabel(
                label: (_selectedCategory != null &&
                        _selectedCategory != _ExamCategory.karisik)
                    ? '3. Soru Sayısı Seç'
                    : '2. Soru Sayısı Seç',
                isDark: _isDark,
              ),
              const SizedBox(height: 14),
              Row(
                children: _questionCounts.map((count) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right:
                              count != _questionCounts.last ? 12 : 0),
                      child: _CountChip(
                        count: count,
                        isSelected: _selectedCount == count,
                        isDark: _isDark,
                        cardBg: _cardBg,
                        borderColor: _borderColor,
                        onTap: () =>
                            setState(() => _selectedCount = count),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 48),

              // ── Başlat ─────────────────────────────────────────────────
              _StartButton(
                canProceed: _canProceed,
                isLoading: _isLoading,
                isDark: _isDark,
                onTap: _confirmAndStart,
              ),

              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Prova sonuçları normal yanlışlarından bağımsız kaydedilir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _subtitleColor.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ders Seçim Butonu
// ─────────────────────────────────────────────────────────────────────────────

class _TopicSelectorButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final Color color;
  final VoidCallback onTap;

  const _TopicSelectorButton({
    required this.label,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.menu_book_rounded,
                          color: color, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFE6EDF3)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: isDark
                            ? Colors.white38
                            : Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ders Seçim BottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class _TopicPickerSheet extends StatelessWidget {
  final Map<String, String> topicMap;
  final String? selectedKey;
  final bool isDark;

  const _TopicPickerSheet({
    required this.topicMap,
    required this.selectedKey,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isDark
        ? const Color(0xFF0D1117).withOpacity(0.92)
        : Colors.white.withOpacity(0.95);
    final Color titleColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade400;

    final sortedEntries = topicMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: isDark
                ? Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.1)))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Ders Seç',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sadece bir derse odaklanmak istersen seç,\nyoksa "Tüm Dersler" ile devam et.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: subtitleColor),
                ),
                const SizedBox(height: 20),

                // Tüm Dersler
                _TopicPickerTile(
                  label: 'Tüm Dersler',
                  icon: Icons.layers_rounded,
                  color: Colors.teal,
                  isSelected: selectedKey == null,
                  isDark: isDark,
                  onTap: () =>
                      Navigator.pop(context, ''), // '' = tümü
                ),

                const SizedBox(height: 8),
                Divider(
                    color: isDark
                        ? Colors.white12
                        : Colors.grey.shade200),
                const SizedBox(height: 8),

                ...sortedEntries.map(
                  (entry) => _TopicPickerTile(
                    label: entry.value,
                    icon: _iconFor(entry.key),
                    color: _colorFor(entry.key),
                    isSelected: selectedKey == entry.key,
                    isDark: isDark,
                    onTap: () =>
                        Navigator.pop(context, entry.key),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String key) {
    const map = {
      'anatomi': Icons.accessibility_new_rounded,
      'biyokimya': Icons.science_rounded,
      'biyoloji': Icons.eco_rounded,
      'farma': Icons.medication_rounded,
      'fizyoloji': Icons.monitor_heart_rounded,
      'histoloji': Icons.biotech_rounded,
      'mikrobiyo': Icons.coronavirus_rounded,
      'patoloji': Icons.sick_rounded,
      'cerrahi': Icons.content_cut_rounded,
      'radyoloji': Icons.sensors_rounded,
      'endo': Icons.medical_services_rounded,
      'orto': Icons.sentiment_satisfied_alt_rounded,
      'pedo': Icons.child_care_rounded,
      'perio': Icons.water_drop_rounded,
      'protetik': Icons.health_and_safety_rounded,
      'resto': Icons.healing_rounded,
    };
    return map[key] ?? Icons.menu_book_rounded;
  }

  Color _colorFor(String key) {
    const map = {
      'anatomi': Colors.orange,
      'biyokimya': Colors.purple,
      'farma': Colors.teal,
      'fizyoloji': Colors.red,
      'histoloji': Colors.pink,
      'mikrobiyo': Colors.green,
      'patoloji': Colors.brown,
      'cerrahi': Colors.redAccent,
      'radyoloji': Colors.blueGrey,
      'endo': Colors.orangeAccent,
      'orto': Colors.indigo,
      'pedo': Colors.amber,
      'perio': Colors.deepOrange,
      'protetik': Colors.lightBlue,
      'resto': Colors.blue,
    };
    return map[key] ?? Colors.grey;
  }
}

class _TopicPickerTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TopicPickerTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(isDark ? 0.15 : 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(color: color.withOpacity(0.4))
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? (isDark ? color.withOpacity(0.9) : color)
                          : (isDark
                              ? const Color(0xFFE6EDF3)
                              : Colors.black87),
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onay BottomSheet
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  final String categoryLabel;
  final String topicLabel;
  final int questionCount;
  final bool isDark;

  const _ConfirmSheet({
    required this.categoryLabel,
    required this.topicLabel,
    required this.questionCount,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isDark
        ? const Color(0xFF0D1117).withOpacity(0.92)
        : Colors.white.withOpacity(0.95);
    final Color titleColor =
        isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: isDark
                ? Border(
                    top: BorderSide(
                        color: Colors.white.withOpacity(0.1)))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white24
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const Text('🎯', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),

                Text(
                  'Sınav Başlıyor!',
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Hazır mısın?',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: subtitleColor),
                ),
                const SizedBox(height: 28),

                _SummaryRow(
                  icon: Icons.category_outlined,
                  label: 'Kategori',
                  value: categoryLabel,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.menu_book_rounded,
                  label: 'Ders',
                  value: topicLabel,
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.quiz_outlined,
                  label: 'Soru Sayısı',
                  value: '$questionCount soru',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _SummaryRow(
                  icon: Icons.shuffle_rounded,
                  label: 'Mod',
                  value: 'Rastgele Karışık',
                  isDark: isDark,
                ),
                const SizedBox(height: 36),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(context, false),
                        child: Text(
                          'Vazgeç',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0xFF1565C0)
                              .withOpacity(0.5),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🚀',
                                style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              'Başlat',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ortak Alt Bileşenler
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.blueGrey.shade400,
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(isDark ? 0.15 : 0.08)
                  : cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : borderColor,
                width: isSelected ? 2 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark
                                    ? color.withOpacity(0.9)
                                    : color)
                                : (isDark
                                    ? const Color(0xFFE6EDF3)
                                    : Colors.black87),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? color
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? color
                                : (isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
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

class _CountChip extends StatelessWidget {
  final int count;
  final bool isSelected;
  final bool isDark;
  final Color cardBg;
  final Color borderColor;
  final VoidCallback onTap;

  const _CountChip({
    required this.count,
    required this.isSelected,
    required this.isDark,
    required this.cardBg,
    required this.borderColor,
    required this.onTap,
  });

  static const _accent = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 90,
          decoration: BoxDecoration(
            color: isSelected
                ? _accent.withOpacity(isDark ? 0.2 : 0.1)
                : cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? _accent : borderColor,
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _accent.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$count',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? _accent
                          : (isDark
                              ? const Color(0xFFE6EDF3)
                              : Colors.black87),
                    ),
                  ),
                  Text(
                    'Soru',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? _accent.withOpacity(0.8)
                          : (isDark
                              ? Colors.white38
                              : Colors.blueGrey.shade400),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool canProceed;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onTap;

  const _StartButton({
    required this.canProceed,
    required this.isLoading,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color active =
        isDark ? const Color(0xFF3B82F6) : const Color(0xFF1565C0);
    final Color inactive =
        isDark ? Colors.white12 : Colors.grey.shade300;

    return GestureDetector(
      onTap: canProceed && !isLoading ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: canProceed ? active : inactive,
          borderRadius: BorderRadius.circular(20),
          boxShadow: canProceed
              ? [
                  BoxShadow(
                    color: active.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Devam Et',
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: canProceed
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color:
                          canProceed ? Colors.white : Colors.white38,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? Colors.white10 : Colors.blueGrey.shade100,
        ),
      ),
      child: Row(
        children: [
          // Sol: ikon + etiket — sabit genişlik
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(icon,
                    size: 18,
                    color: isDark
                        ? Colors.white38
                        : Colors.blueGrey.shade400),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white38
                        : Colors.blueGrey.shade400,
                  ),
                ),
              ],
            ),
          ),
          // Sağ: değer
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? const Color(0xFFE6EDF3)
                    : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
