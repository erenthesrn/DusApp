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
  // Dinamik olarak birleştirilmiş liste burada tutulacak
  Map<String, List<Map<String, dynamic>>> _finalData = {};
  Map<String, dynamic> _customCategoryIcons = {}; // Artık hem int (ikon) hem String (emoji) tutacak

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

    // Profil sayfası ile tamamen aynı arka plan tanımı
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
        extendBodyBehindAppBar: true, 
        backgroundColor: Colors.transparent, 
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
            background, 
            StreamBuilder<QuerySnapshot>(
              stream: _getFlashcardsStream(),
              builder: (context, snapshot) {
                _finalData = {}; // Sadece Firebase'den gelen verileri tutacağız

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    String category = data['category'] ?? "Genel";
                    String question = data['question'] ?? "";
                    String answer = data['answer'] ?? "";

                    if (data.containsKey('iconEmoji')) {
                      _customCategoryIcons[category] = data['iconEmoji'];
                    } else if (data.containsKey('iconCode')) {
                      _customCategoryIcons[category] = data['iconCode'];
                    }

                    if (!_finalData.containsKey(category)) {
                      _finalData[category] = [];
                    }
                    _finalData[category]!.add({"q": question, "a": answer, "id": doc.id});
                  }
                }

                if (_finalData.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.style, size: 80, color: isDark ? Colors.white24 : Colors.black12),
                        const SizedBox(height: 16),
                        Text("Henüz hiç bilgi kartın yok.", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
                        const SizedBox(height: 8),
                        Text("Aşağıdaki butondan ilk desteni oluştur!", style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 130, 20, 100),
                  children: _finalData.keys.map((category) {
                    // 🔥 YENİ: Sola kaydırarak tüm desteyi silme
                    return Dismissible(
                      key: Key(category),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                      ),
                      confirmDismiss: (direction) => _confirmDeleteCategory(category),
                      child: _buildCategoryCard(category, _finalData[category]!.length, isDark),
                    );
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
      return _buildResultScreen(isDark, textColor, background); 
    }

    // KART GÖSTERİM EKRANI
    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: Colors.transparent, 
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
          background, 
          Padding(
            padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _currentCards.isEmpty ? 0 : (_currentIndex + 1) / _currentCards.length,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  color: const Color(0xFF448AFF),
                  minHeight: 4,
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _currentCards.isEmpty ? "0 / 0" : "${_currentIndex + 1} / ${_currentCards.length}",
                          style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildMiniIcon(Icons.add_rounded, const Color(0xFF00BFA5), () => _showAddCardDialog(context, isDark, prefilledCategory: _selectedCategory)),
                            // 🔥 YENİ: Deste Yönetimi (Tüm soruları gör)
                            _buildMiniIcon(Icons.list_alt_rounded, const Color(0xFF448AFF), () => _openCategoryManager(isDark)),
                            _buildMiniIcon(Icons.shuffle_rounded, Colors.orangeAccent, () {
                              if (_currentCards.isNotEmpty) {
                                setState(() {
                                  _currentCards.shuffle();
                                  _currentIndex = 0;
                                  _isFlipped = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kartlar karıştırıldı 🔀"), backgroundColor: Colors.orange, duration: Duration(seconds: 1)));
                              }
                            }),
                            if (_currentCards.isNotEmpty && _currentIndex < _currentCards.length) ...[
                              Container(width: 1, height: 16, color: isDark ? Colors.white24 : Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
                              _buildMiniIcon(Icons.edit_rounded, Colors.blueAccent, () => _showEditCardDialog(context, isDark, _currentCards[_currentIndex])),
                              _buildMiniIcon(Icons.delete_outline_rounded, Colors.redAccent, () => _deleteCard(_currentCards[_currentIndex]['id'])),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                                        _currentCards.isNotEmpty ? _currentCards[_currentIndex]['a']! : "", 
                                        isBack: true, 
                                        isDark: isDark,
                                        cardColor: cardColor,
                                        textColor: textColor
                                      ),
                                    )
                                  : _buildCardContent(
                                      _currentCards.isNotEmpty ? _currentCards[_currentIndex]['q']! : "", 
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

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, required bool isDarkMode}) {
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

  void _showAddCardDialog(BuildContext context, bool isDark, {String? prefilledCategory}) {
    final TextEditingController categoryCtrl = TextEditingController(text: prefilledCategory ?? "");
    final TextEditingController questionCtrl = TextEditingController();
    final TextEditingController answerCtrl = TextEditingController();

    final List<IconData> iconList = [
      Icons.style, Icons.science, Icons.monitor_heart, Icons.biotech,
      Icons.coronavirus, Icons.health_and_safety, Icons.medical_services,
      Icons.medication, Icons.accessibility_new, Icons.psychology,
      Icons.bloodtype, Icons.vaccines, Icons.healing, Icons.local_hospital,
      Icons.medical_information, Icons.masks, Icons.sanitizer, Icons.clean_hands,
      Icons.child_care, Icons.pregnant_woman, Icons.elderly, Icons.personal_injury,
      Icons.visibility, Icons.hearing, Icons.thermostat, Icons.water_drop,
      Icons.air, Icons.hub, Icons.bug_report, Icons.face_retouching_natural,
      Icons.sentiment_satisfied_alt, Icons.emergency, Icons.shield,
      Icons.menu_book, Icons.star_rounded, Icons.bolt_rounded, Icons.favorite_rounded
    ];
    IconData? selectedIcon = Icons.style; 
    String? selectedEmoji; 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(innerContext).viewInsets.bottom + 20, 
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
                  const SizedBox(height: 16),
                  
                  Text("Deste İkonu Seç (Kendi Emojini Eklemek İçin + Kullan)", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade400 : Colors.blueGrey)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 50,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: iconList.length + 1, 
                      itemBuilder: (listContext, index) {
                        if (index == iconList.length) {
                          final isEmojiSelected = selectedEmoji != null;
                          return GestureDetector(
                            onTap: () async {
                              String? emoji = await showDialog<String>(
                                context: innerContext,
                                builder: (BuildContext context) {
                                  TextEditingController emojiCtrl = TextEditingController();
                                  return AlertDialog(
                                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                                    title: Text("Klavye Emojisi Gir", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
                                    content: TextField(
                                      controller: emojiCtrl,
                                      maxLength: 3, 
                                      style: const TextStyle(fontSize: 32),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        hintText: "🦷", 
                                        hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
                                      TextButton(onPressed: () => Navigator.pop(context, emojiCtrl.text), child: const Text("Seç")),
                                    ],
                                  );
                                }
                              );
                              
                              if (emoji != null && emoji.trim().isNotEmpty) {
                                setModalState(() {
                                  selectedEmoji = emoji.trim();
                                  selectedIcon = null; 
                                });
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isEmojiSelected ? const Color(0xFF0D47A1) : (isDark ? Colors.white10 : Colors.grey.shade100),
                                shape: BoxShape.circle,
                                border: Border.all(color: isEmojiSelected ? const Color(0xFF0D47A1) : Colors.transparent, width: 2)
                              ),
                              child: isEmojiSelected
                                  ? Center(child: Text(selectedEmoji!, style: const TextStyle(fontSize: 18)))
                                  : Icon(Icons.add, color: isDark ? Colors.grey : Colors.blueGrey, size: 24),
                            ),
                          );
                        }

                        final currentIcon = iconList[index];
                        final isSelected = currentIcon == selectedIcon && selectedEmoji == null;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedIcon = currentIcon;
                              selectedEmoji = null; 
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0D47A1) : (isDark ? Colors.white10 : Colors.grey.shade100),
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.transparent, width: 2)
                            ),
                            child: Icon(currentIcon, color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.blueGrey), size: 24),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField(questionCtrl, "Soru", isDark, Icons.help_outline, maxLines: 2),
                  const SizedBox(height: 12),
                  _buildTextField(answerCtrl, "Cevap", isDark, Icons.lightbulb_outline, maxLines: 3),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (categoryCtrl.text.isEmpty || questionCtrl.text.isEmpty || answerCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(innerContext).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldur!")));
                          return;
                        }

                        Map<String, dynamic> cardData = {
                          'category': categoryCtrl.text.trim(),
                          'question': questionCtrl.text.trim(),
                          'answer': answerCtrl.text.trim(),
                          'createdAt': FieldValue.serverTimestamp(),
                        };

                        if (selectedEmoji != null) {
                          cardData['iconEmoji'] = selectedEmoji;
                        } else if (selectedIcon != null) {
                          cardData['iconCode'] = selectedIcon!.codePoint;
                        }
                        
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcards').add(cardData);
                          Navigator.pop(innerContext);
                          ScaffoldMessenger.of(innerContext).showSnackBar(const SnackBar(content: Text("Kart başarıyla eklendi! 🎉"), backgroundColor: Colors.green));
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

  Widget _buildCategoryCard(String title, int count, bool isDark) {
    Color iconColor = Colors.blue;
    Widget iconWidget = const Icon(Icons.style, color: Colors.blue);
    
    if (_customCategoryIcons.containsKey(title)) {
      iconColor = const Color(0xFF00BFA5);
      final customIcon = _customCategoryIcons[title];
      if (customIcon is String) {
        iconWidget = Text(customIcon, style: const TextStyle(fontSize: 22));
      } else {
        iconWidget = Icon(IconData(customIcon, fontFamily: 'MaterialIcons'), color: iconColor);
      }
    } else if(title == "Anatomi") { 
      iconColor = Colors.orange; 
      iconWidget = Icon(Icons.accessibility_new, color: iconColor);
    } else if(title == "Fizyoloji") { 
      iconColor = Colors.red; 
      iconWidget = Icon(Icons.monitor_heart, color: iconColor);
    }
    
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
          child: iconWidget, 
        ),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87)),
        subtitle: Text("$count Kart", style: GoogleFonts.inter(color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

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

  Widget _buildResultScreen(bool isDark, Color textColor, Widget background) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      backgroundColor: Colors.transparent, 
      body: Stack(
        children: [
          background, 
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

  void _showEditCardDialog(BuildContext context, bool isDark, Map<String, dynamic> cardData) {
    final TextEditingController questionCtrl = TextEditingController(text: cardData['q']);
    final TextEditingController answerCtrl = TextEditingController(text: cardData['a']);
    final String? docId = cardData['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20, 
            left: 24, right: 24, top: 24
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Kartı Düzenle", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              
              _buildTextField(questionCtrl, "Soru", isDark, Icons.help_outline, maxLines: 2),
              const SizedBox(height: 12),
              _buildTextField(answerCtrl, "Cevap", isDark, Icons.lightbulb_outline, maxLines: 3),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (questionCtrl.text.isEmpty || answerCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text("Lütfen tüm alanları doldur!")));
                      return;
                    }
                    
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user != null && docId != null) {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcards').doc(docId).update({
                        'question': questionCtrl.text.trim(),
                        'answer': answerCtrl.text.trim(),
                      });
                      
                      setState(() {
                        cardData['q'] = questionCtrl.text.trim();
                        cardData['a'] = answerCtrl.text.trim();
                      });
                      
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kart başarıyla güncellendi! ✅"), backgroundColor: Colors.green));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BFA5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Değişiklikleri Kaydet", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  void _deleteCard(String? docId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
          title: Text("Kartı Sil", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text("Bu bilgi kartını kalıcı olarak silmek istediğine emin misin?", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("İptal", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null && docId != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcards').doc(docId).delete();
                }
                Navigator.pop(dialogContext); 
                
                setState(() {
                  _currentCards.removeAt(_currentIndex);
                  if (_currentIndex >= _currentCards.length && _currentIndex > 0) {
                    _currentIndex--;
                  }
                  _isFlipped = false;
                  if (_currentCards.isEmpty) {
                    _selectedCategory = null;
                  }
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kart silindi 🗑️"), backgroundColor: Colors.red));
              },
              child: const Text("Evet, Sil", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  // 🔥 YENİ: TÜM DESTEYİ SİLME ONAYI
  Future<bool> _confirmDeleteCategory(String category) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
        title: Text("Desteyi Sil?", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
        content: Text("'$category' destesindeki tüm sorular kalıcı olarak silinecek. Emin misin?", style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SİL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        var snapshots = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('flashcards').where('category', isEqualTo: category).get();
        for (var doc in snapshots.docs) { await doc.reference.delete(); }
        setState(() { _selectedCategory = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$category destesi silindi 🗑️")));
      }
    }
    return confirm;
  }

  // 🔥 YENİ: GENİŞ DÜZENLEME SAYFASINI AÇ
  void _openCategoryManager(bool isDark) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryManagerPage(
      category: _selectedCategory!,
      cards: _finalData[_selectedCategory!]!,
      isDark: isDark,
      onUpdate: () => setState(() {}),
      buildTextField: _buildTextField, 
    )));
  }

  Widget _buildMiniIcon(IconData icon, Color color, VoidCallback onTap) {
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36), 
      splashRadius: 18,
      iconSize: 20,
      icon: Icon(icon, color: color),
      onPressed: onTap,
    );
  }
}

// 🔥 YENİ: GENİŞ DÜZENLEME SAYFASI (TAM SAYFA)
class CategoryManagerPage extends StatelessWidget {
  final String category;
  final List<Map<String, dynamic>> cards;
  final bool isDark;
  final VoidCallback onUpdate;
  final Function buildTextField;

  const CategoryManagerPage({super.key, required this.category, required this.cards, required this.isDark, required this.onUpdate, required this.buildTextField});

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF0A0E14) : const Color.fromARGB(255, 224, 247, 250);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("$category - Tüm Sorular", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Card(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(card['q'], maxLines: 2, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
              subtitle: Text(card['a'], maxLines: 2, style: const TextStyle(color: Colors.grey)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
                onPressed: () async {
                  User? user = FirebaseAuth.instance.currentUser;
                  await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('flashcards').doc(card['id']).delete();
                  onUpdate();
                  Navigator.pop(context); // Sayfayı yenilemek için geri atıyoruz
                }
              ),
            ),
          );
        },
      ),
    );
  }
}