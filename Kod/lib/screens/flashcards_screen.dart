import 'dart:math';
import 'dart:ui'; // 🔥 YENİ: Blur efekti için eklendi
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  // --- 1. STATİK (UYGULAMA İÇİNDEN GELEN) VERİLER ---
  final Map<String, List<Map<String, dynamic>>> _staticData = {
    "Anatomi": [
      {"q": "Fossa cubitalis'in dış sınırını oluşturan kas hangisidir?", "a": "M. brachioradialis"},
      {"q": "Nervus ulnaris hangi epikondilin arkasından geçer?", "a": "Medial epikondil"},
      {"q": "Kalbin venöz drenajının büyük kısmı nereye dökülür?", "a": "Sinus coronarius"},
    ],
    "Fizyoloji": [
      {"q": "Hücre içi sıvıda en çok bulunan katyon hangisidir?", "a": "Potasyum (K+)"},
      {"q": "Frank-Starling yasası neyi ifade eder?", "a": "Kalbe gelen kan miktarı arttıkça kasılma gücünün artması"},
    ],
    "Biyokimya": [
      {"q": "Glikolizin hız kısıtlayıcı enzimi hangisidir?", "a": "Fosfofruktokinaz-1 (PFK-1)"},
    ],
    "Farmakoloji": [
      {"q": "Aspirin'in etki mekanizması nedir?", "a": "Tromboksan A2 sentezini inhibe eder"},
    ],
  };

  // Dinamik olarak birleştirilmiş liste burada tutulacak
  Map<String, List<Map<String, dynamic>>> _finalData = {};

  String? _selectedCategory;
  List<Map<String, dynamic>> _currentCards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  
  // İstatistikler
  int _knownCount = 0;
  int _unknownCount = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);

    // 🔥 YENİ: Profil sayfası ile tamamen aynı arka plan tanımı
    Widget background = isDark
      ? Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
            )
          ),
        )
      : Container(color: const Color.fromARGB(255, 224, 247, 250));

    // Kategori Seçilmediyse Listeyi Göster
    if (_selectedCategory == null) {
      return Scaffold(
        extendBodyBehindAppBar: true, // 🔥 YENİ: Glass effect için
        backgroundColor: Colors.transparent, // 🔥 YENİ: Arka planı transparan yapıyoruz
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddCardDialog(context, isDark),
          backgroundColor: const Color(0xFF0D47A1),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text("Yeni Kart Ekle", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(color: textColor),
          title: Text("Bilgi Kartları", style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
          // 🔥 YENİ: AppBar Blur Efekti
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: (isDark ? const Color(0xFF0D1117) : Colors.white).withOpacity(0.5),
              ),
            ),
          ),
        ),
        // 🔥 FIREBASE STREAM BUILDER (Verileri Canlı Dinle)
        body: Stack(
          children: [
            background, // 🔥 YENİ: Arka Plan eklendi
            StreamBuilder<QuerySnapshot>(
              stream: _getFlashcardsStream(),
              builder: (context, snapshot) {
                // 1. Statik verileri önce bir kopyala
                _finalData = Map.from(_staticData);

                // 2. Firebase'den gelen verileri statik verinin üzerine ekle
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String category = data['category'] ?? "Genel";
                    String question = data['question'] ?? "";
                    String answer = data['answer'] ?? "";

                    if (!_finalData.containsKey(category)) {
                      _finalData[category] = [];
                    }
                    _finalData[category]!.add({"q": question, "a": answer});
                  }
                }

                // 3. Listeyi Oluştur
                return ListView(
                  // 🔥 YENİ: AppBar'ın altında kalmaması için top padding artırıldı
                  padding: EdgeInsets.fromLTRB(20, kToolbarHeight + MediaQuery.of(context).padding.top + 20, 20, 20),
                  children: _finalData.keys.map((category) {
                    return _buildCategoryCard(category, _finalData[category]!.length, isDark);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
    }

    // Kartlar Bittiyse Sonuç Ekranı
    if (_currentIndex >= _currentCards.length) {
      return _buildResultScreen(isDark, textColor, background); // background parametre olarak eklendi
    }

    // KART GÖSTERİM EKRANI
    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 YENİ: Glass effect için
      backgroundColor: Colors.transparent, // 🔥 YENİ: Arka planı transparan yapıyoruz
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => setState(() {
            _selectedCategory = null;
            _currentIndex = 0;
            _knownCount = 0;
            _unknownCount = 0;
          }),
        ),
        title: Text(_selectedCategory!, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                "${_currentIndex + 1}/${_currentCards.length}",
                style: GoogleFonts.inter(color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
        // 🔥 YENİ: AppBar Blur Efekti
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: (isDark ? const Color(0xFF0D1117) : Colors.white).withOpacity(0.5),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          background, // 🔥 YENİ: Arka Plan eklendi
          Padding(
            // 🔥 YENİ: Content AppBar altında kalmasın diye padding
            padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                // Progress Bar
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _currentCards.length,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  color: const Color(0xFF448AFF),
                  minHeight: 4,
                ),
                
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0, end: _isFlipped ? 180 : 0),
                          duration: const Duration(milliseconds: 500),
                          builder: (context, double value, child) {
                            bool isBack = value >= 90;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001) 
                                ..rotateY(value * pi / 180),
                              child: isBack
                                  ? Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.identity()..rotateY(pi), 
                                      child: _buildCardContent(
                                        _currentCards[_currentIndex]['a']!, 
                                        isBack: true, 
                                        isDark: isDark,
                                        cardColor: cardColor,
                                        textColor: textColor
                                      ),
                                    )
                                  : _buildCardContent(
                                      _currentCards[_currentIndex]['q']!, 
                                      isBack: false, 
                                      isDark: isDark,
                                      cardColor: cardColor,
                                      textColor: textColor
                                    ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // --- 🔥 GÜNCELLENEN BUTON ALANI (PREMIUM TASARIM) ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildActionButton( 
                          label: "Hatırlayamadım", 
                          icon: Icons.close_rounded, 
                          color: Colors.red.shade400, 
                          onTap: () => _nextCard(false),
                          isDarkMode: isDark, 
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildActionButton( 
                          label: "Biliyorum", 
                          icon: Icons.check_rounded, 
                          color: const Color(0xFF00BFA5), 
                          onTap: () => _nextCard(true),
                          isDarkMode: isDark, 
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 🔥 GÜNCELLENEN BUTON TASARIMI (ESKİ TASARIMIN ENTEGRASYONU) ---
  Widget _buildActionButton({
    required String label, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap, 
    required bool isDarkMode
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5), 
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 🔥 YENİ EKLENEN: KART EKLEME DİYALOĞU ---
  void _showAddCardDialog(BuildContext context, bool isDark) {
    final TextEditingController categoryCtrl = TextEditingController();
    final TextEditingController questionCtrl = TextEditingController();
    final TextEditingController answerCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
            left: 24, 
            right: 24, 
            top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Kendi Kartını Oluştur", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              
              _buildTextField(categoryCtrl, "Deste Başlığı (Örn: Patoloji)", isDark, Icons.folder_open),
              const SizedBox(height: 12),
              _buildTextField(questionCtrl, "Soru", isDark, Icons.help_outline, maxLines: 2),
              const SizedBox(height: 12),
              _buildTextField(answerCtrl, "Cevap", isDark, Icons.lightbulb_outline, maxLines: 3),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (categoryCtrl.text.isEmpty || questionCtrl.text.isEmpty || answerCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldur!")));
                      return;
                    }
                    
                    // Firebase'e Kaydet
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcards').add({
                        'category': categoryCtrl.text.trim(),
                        'question': questionCtrl.text.trim(),
                        'answer': answerCtrl.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context); // Kapat
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kart başarıyla eklendi! 🎉"), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Desteye Ekle", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey.shade600),
        prefixIcon: Icon(icon, color: isDark ? Colors.grey : Colors.blueGrey),
        filled: true,
        fillColor: isDark ? Colors.black26 : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Stream<QuerySnapshot> _getFlashcardsStream() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('flashcards')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Kategori Kartı Tasarımı ---
  Widget _buildCategoryCard(String title, int count, bool isDark) {
    // Hazır kategoriler için ikonlar
    IconData icon = Icons.style;
    Color iconColor = Colors.blue;
    if(title == "Anatomi") { icon = Icons.accessibility_new; iconColor = Colors.orange; }
    else if(title == "Fizyoloji") { icon = Icons.monitor_heart; iconColor = Colors.red; }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        onTap: () {
          setState(() {
            _selectedCategory = title;
            _currentCards = List.from(_finalData[title]!)..shuffle(); 
            _currentIndex = 0;
            _isFlipped = false;
          });
        },
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text("$count Kart", style: GoogleFonts.inter(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  // --- Flashcard İçeriği ---
  Widget _buildCardContent(String text, {required bool isBack, required bool isDark, required Color cardColor, required Color textColor}) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isBack 
            ? const Color(0xFF00BFA5).withOpacity(0.5) 
            : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isBack ? 2 : 1
        ),
        boxShadow: [
          BoxShadow(
            color: isBack 
                ? const Color(0xFF00BFA5).withOpacity(0.2) 
                : Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              isBack ? Icons.lightbulb : Icons.help_outline,
              size: 150,
              color: (isBack ? Colors.teal : Colors.blue).withOpacity(0.05),
            ),
          ),
          
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isBack ? "CEVAP" : "SORU",
                    style: GoogleFonts.inter(
                      fontSize: 14, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 2,
                      color: isBack ? Colors.teal : Colors.blue
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  if (!isBack) ...[
                     const SizedBox(height: 40),
                     Text(
                       "(Cevabı görmek için dokun)",
                       style: TextStyle(color: Colors.grey.withOpacity(0.6), fontSize: 12),
                     )
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Sonuç Ekranı ---
  Widget _buildResultScreen(bool isDark, Color textColor, Widget background) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 YENİ: Uyum için eklendi
      backgroundColor: Colors.transparent, // 🔥 YENİ
      body: Stack(
        children: [
          background, // 🔥 YENİ: Arka Plan eklendi
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, size: 80, color: Colors.orange),
                  const SizedBox(height: 24),
                  Text(
                    "Tebrikler!",
                    style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "$_selectedCategory setini tamamladın.",
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(child: _buildStatBox("Biliyorum", "$_knownCount", Colors.teal, isDark)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatBox("Tekrar Et", "$_unknownCount", Colors.red, isDark)),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                         setState(() {
                           _selectedCategory = null; 
                         });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Yeni Set Seç", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatBox(String title, String count, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(count, style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  // --- Mantıksal Fonksiyonlar ---
  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  void _nextCard(bool known) {
    if (known) _knownCount++; else _unknownCount++;
    
    if (_currentIndex < _currentCards.length) {
      setState(() {
        _currentIndex++;
        _isFlipped = false; 
      });
    }
  }
}