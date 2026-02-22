// lib/screens/topic_selection_screen.dart

import 'dart:ui'; // Blur efekti için
import 'package:flutter/material.dart';
import 'test_list_screen.dart';

class TopicSelectionScreen extends StatefulWidget {
  final String title;
  final List<String> topics;
  final Color themeColor; 

  const TopicSelectionScreen({
    super.key, 
    required this.title, 
    required this.topics,
    required this.themeColor,
  });

  @override
  State<TopicSelectionScreen> createState() => _TopicSelectionScreenState();
}

class _TopicSelectionScreenState extends State<TopicSelectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Liste elemanlarının sırayla gelmesi için animasyon kontrolcüsü
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- AKILLI İKON SİSTEMİ ---
  // Ders ismine göre en uygun, modern Material ikonu seçer
  IconData _getIconForTopic(String topic) {
    final t = topic.toLowerCase();
    
    // Temel Bilimler
    if (t.contains('anatomi')) return Icons.accessibility_new_rounded; // Vücut
    if (t.contains('biyoloji')) return Icons.fingerprint_rounded; // Genetik/DNA
    if (t.contains('biyokimya')) return Icons.science_rounded; // Deney Tüpü
    if (t.contains('farmakoloji')) return Icons.medication_rounded; // İlaç
    if (t.contains('fizyoloji')) return Icons.monitor_heart_rounded; // Kalp Atışı
    if (t.contains('histoloji')) return Icons.biotech_rounded; // Mikroskop
    if (t.contains('mikrobiyoloji')) return Icons.coronavirus_rounded; // Virüs/Bakteri
    if (t.contains('patoloji')) return Icons.health_and_safety_rounded; // Kalkan/Hastalık
    
    // Klinik Bilimler
    if (t.contains('cerrahi')) return Icons.medical_services_rounded; // Cerrahi Müdahale
    if (t.contains('radyoloji')) return Icons.camera_alt_rounded; // Röntgen
    if (t.contains('endodonti')) return Icons.flash_on_rounded; // Sinir/Kök
    if (t.contains('ortodonti')) return Icons.grid_on_rounded; // Tel/Düzen
    if (t.contains('restoratif')) return Icons.build_circle_rounded; // Onarım
    if (t.contains('pedodonti')) return Icons.child_care_rounded; // Çocuk
    if (t.contains('periodontoloji')) return Icons.layers_rounded; // Diş Eti Tabakaları
    if (t.contains('protetik')) return Icons.sentiment_satisfied_alt_rounded; // Gülüş Tasarımı

    return Icons.menu_book_rounded; // Varsayılan Kitap
  }

  @override
  Widget build(BuildContext context) {
    // 1. Tema Kontrolü
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 2. Renk Tanımları
    Color appBarTitleColor = isDarkMode ? const Color(0xFFE6EDF3) : Colors.black87;

    // Profil sayfası ile tamamen aynı arka plan tanımı
    Widget background = isDarkMode
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

    return Scaffold(
      extendBodyBehindAppBar: true, // Glass effect için
      backgroundColor: Colors.transparent, // Arka planı transparan yapıyoruz
      appBar: AppBar(
        title: Text(
          widget.title, 
          style: TextStyle(
            fontWeight: FontWeight.w800, 
            color: appBarTitleColor,
            letterSpacing: 0.5
          )
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: IconThemeData(color: appBarTitleColor),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            // Profil sayfası ile aynı AppBar blur arka plan rengi
            child: Container(
              color: (isDarkMode ? const Color(0xFF0D1117) : Colors.white).withOpacity(0.5),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Profil ekranındaki Arka Plan Widget'ı en alta eklendi
          background,

          // Arka Plan Glow Efekti (Dinamik Renkli - Sağ Üst Köşe)
          if (isDarkMode)
            Positioned(
              top: -100, right: -100,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.themeColor.withOpacity(0.15),
                  ),
                ),
              ),
            ),
            
          // Sol Alt Glow (Dengeleyici)
           if (isDarkMode)
            Positioned(
              bottom: -50, left: -50,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.1),
                  ),
                ),
              ),
            ),

          // Liste
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 130, 20, 40), // AppBar payı bırakıldı
            physics: const BouncingScrollPhysics(),
            itemCount: widget.topics.length,
            itemBuilder: (context, index) {
              // Her eleman için gecikmeli animasyon
              final Animation<double> animation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    (1 / widget.topics.length) * index, 
                    1.0, 
                    curve: Curves.easeOut
                  ),
                ),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 40 * (1 - animation.value)), // Aşağıdan yukarı kayma
                    child: Opacity(
                      opacity: animation.value,
                      child: _buildPremiumCard(context, widget.topics[index], isDarkMode),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, String topic, bool isDarkMode) {
    // Kart Renkleri
    Color cardColor = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    Color textColor = isDarkMode ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    Color borderColor = isDarkMode ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.1);
    
    // İkon Belirle
    IconData iconData = _getIconForTopic(topic);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 90, // Sabit yükseklik ile daha düzenli görünüm
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24), // Daha yuvarlak köşeler
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: widget.themeColor.withOpacity(0.1),
          highlightColor: widget.themeColor.withOpacity(0.05),
          onTap: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => TestListScreen(
                topic: topic, 
                themeColor: widget.themeColor, 
              ))
            );              
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // 1. Sol İkon (Gradient Background & Glow)
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.themeColor.withOpacity(0.2),
                        widget.themeColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.themeColor.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: widget.themeColor.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                      )
                    ]
                  ),
                  child: Icon(iconData, color: widget.themeColor, size: 28),
                ),
                
                const SizedBox(width: 20),
                
                // 2. Başlık ve Alt Metin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        topic,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 12, color: widget.themeColor.withOpacity(0.7)),
                          const SizedBox(width: 4),
                          Text(
                            "Testlere Başla", 
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 3. Sağ Ok İkonu (Minimal)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded, 
                    size: 18, 
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400]
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}