// lib/screens/onboarding_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart'; // İşlem bitince ana sayfaya atmak için

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // Seçilen verileri tutacak değişkenler
  String? _selectedStatus; // Öğrenci / Mezun
  int? _selectedDailyGoal; // Süre hedefi (Dakika)
  String? _selectedBranch; // Hedef Uzmanlık

  // 🔥 YENİ: Soru hedefi için kontrolcü
  final TextEditingController _questionGoalController = TextEditingController();

  bool _isLoading = false;
  String _userName = "Doktor"; // Kullanıcının ismi (Hitap için)

  @override
  void initState() {
    super.initState();
    _fetchUserName();
  }

  @override
  void dispose() {
    _questionGoalController.dispose(); // Bellek sızıntısını önle
    super.dispose();
  }

  // Kullanıcının ismini çekip "Hoş geldin Ahmet" demek için
  void _fetchUserName() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? "Doktor";
      });
    }
  }

  // Verileri Kaydet ve Devam Et
  Future<void> _saveAndContinue() async {
    // 🔥 Validasyonları Güncelledik (Soru hedefi kontrolü eklendi)
    if (_selectedStatus == null || _selectedDailyGoal == null || _selectedBranch == null || _questionGoalController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen tüm alanları doldurarak hedefini belirle. 😇"), backgroundColor: Colors.orange),
      );
      return;
    }

    // Soru hedefinin sayı olup olmadığını kontrol et
    int? questionGoal = int.tryParse(_questionGoalController.text);
    if (questionGoal == null || questionGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen geçerli bir soru sayısı giriniz."), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Firestore'daki kullanıcı belgesini güncelle
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'status': _selectedStatus,
          'dailyGoalMinutes': _selectedDailyGoal,   // Süre Hedefi
          'dailyQuestionGoal': questionGoal,       // 🔥 YENİ: Soru Hedefi
          'targetBranch': _selectedBranch,
          'isOnboardingComplete': true, // Artık bu ekranı görmesin
        });

        if (mounted) {
          // Ana Sayfaya Gönder
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata oluştu: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Çok açık gri/beyaz
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 0, // AppBar'ı gizle ama status bar kalsın
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BAŞLIK ALANI ---
              Text(
                "Aramıza Hoş Geldin,\n$_userName! 👋",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                "Seni daha yakından tanımak ve çalışma programını sana özel hazırlamak istiyoruz.",
                style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
              ),
              const SizedBox(height: 32),

              // --- 1. SORU: DURUMUN ---
              _buildSectionTitle("Şu anki durumun nedir?"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: [
                  _buildSelectableChip("Dönem 3 Öğrencisi"),
                  _buildSelectableChip("Dönem 4 Öğrencisi"),
                  _buildSelectableChip("Dönem 5 Öğrencisi"),
                  _buildSelectableChip("Mezun / Diş Hekimi"),
                ],
              ),
              
              const SizedBox(height: 32),

              // --- 2. SORU: GÜNLÜK SÜRE HEDEFİ ---
              _buildSectionTitle("Günlük çalışma SÜRESİ hedefin?"),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTimeChip(30, "Isınma"),
                    const SizedBox(width: 10),
                    _buildTimeChip(60, "İdeal"),
                    const SizedBox(width: 10),
                    _buildTimeChip(120, "Ciddi"),
                    const SizedBox(width: 10),
                    _buildTimeChip(180, "Hardcore"),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- 3. SORU: GÜNLÜK SORU HEDEFİ (🔥 YENİ EKLENEN KISIM) ---
              _buildSectionTitle("Günde kaç SORU çözmeyi hedefliyorsun?"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: TextField(
                  controller: _questionGoalController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Örn: 100",
                    hintStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.normal),
                    suffixText: "Soru",
                    suffixStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                    icon: Icon(Icons.edit_note, color: Color(0xFF1565C0)),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- 4. SORU: HEDEF UZMANLIK ---
              _buildSectionTitle("Hangi uzmanlığı kazanmak istiyorsun?"),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildRadioTile("Radyoloji"),
                    _buildDivider(),                    
                    _buildRadioTile("Endodonti"),
                    _buildDivider(),
                    _buildRadioTile("Cerrahi"),
                    _buildDivider(),
                    _buildRadioTile("Pedodonti"),
                    _buildDivider(),
                    _buildRadioTile("Periodontoloji"),
                    _buildDivider(),                    
                    _buildRadioTile("Ortodonti"),
                    _buildDivider(),
                    _buildRadioTile("Protetik"),
                    _buildDivider(),
                    _buildRadioTile("Restoratif"),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- KAYDET BUTONU ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: Colors.blue.withOpacity(0.4),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Hemen Başla 🚀",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }

  // Durum Seçimi İçin Chip (Öğrenci/Mezun)
  Widget _buildSelectableChip(String label) {
    bool isSelected = _selectedStatus == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFE3F2FD),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1565C0) : Colors.black54,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (bool selected) {
        setState(() {
          _selectedStatus = label;
        });
      },
    );
  }

  // Süre Seçimi İçin Özel Chip
  Widget _buildTimeChip(int minutes, String label) {
    bool isSelected = _selectedDailyGoal == minutes;
    return GestureDetector(
      onTap: () => setState(() => _selectedDailyGoal = minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300),
          boxShadow: isSelected 
              ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
              : [],
        ),
        child: Column(
          children: [
            Text(
              "$minutes dk",
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Uzmanlık Seçimi İçin Satır
  Widget _buildRadioTile(String title) {
    bool isSelected = _selectedBranch == title;
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check_circle, color: Color(0xFF1565C0)) 
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () {
        setState(() {
          _selectedBranch = title;
        });
      },
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, indent: 60, endIndent: 20, color: Color(0xFFF0F0F0));
  }
}