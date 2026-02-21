// lib/screens/offline_manager_screen.dart

import 'dart:ui'; // Blur efekti için eklendi
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/offline_service.dart';

class OfflineManagerScreen extends StatefulWidget {
  const OfflineManagerScreen({super.key});

  @override
  State<OfflineManagerScreen> createState() => _OfflineManagerScreenState();
}

class _OfflineManagerScreenState extends State<OfflineManagerScreen> {
  List<String> _downloadedTopics = [];
  int _pendingCount = 0;
  bool _isLoading = true;
  
  // Tüm mevcut konular ve özel İKONLARI
  final List<Map<String, dynamic>> _allTopics = [
    {
      "name": "Anatomi", 
      "color": const Color(0xFFFB8C00), 
      "icon": Icons.accessibility_new_rounded
    },
    {
      "name": "Histoloji", 
      "color": const Color(0xFFEC407A), 
      "icon": Icons.biotech_rounded
    },
    {
      "name": "Fizyoloji", 
      "color": const Color(0xFFEF5350), 
      "icon": Icons.monitor_heart_rounded
    },
    {
      "name": "Biyokimya", 
      "color": const Color(0xFFAB47BC), 
      "icon": Icons.science_rounded
    },
    {
      "name": "Mikrobiyoloji", 
      "color": const Color(0xFF66BB6A), 
      "icon": Icons.coronavirus_rounded
    },
    {
      "name": "Patoloji", 
      "color": const Color(0xFF8D6E63), 
      "icon": Icons.health_and_safety_rounded
    },
    {
      "name": "Farmakoloji", 
      "color": const Color(0xFF26A69A), 
      "icon": Icons.medication_rounded
    },
    {
      "name": "Biyoloji", 
      "color": const Color(0xFFD4E157), 
      "icon": Icons.fingerprint_rounded
    },
    {
      "name": "Protetik", 
      "color": const Color(0xFF29B6F6), 
      "icon": Icons.sentiment_satisfied_alt_rounded
    },
    {
      "name": "Restoratif", 
      "color": const Color(0xFF42A5F5), 
      "icon": Icons.build_circle_rounded
    },
    {
      "name": "Endodonti", 
      "color": const Color(0xFFFFA726), 
      "icon": Icons.flash_on_rounded
    },
    {
      "name": "Perio", 
      "color": const Color(0xFFFF7043), 
      "icon": Icons.layers_rounded
    },
    {
      "name": "Ortodonti", 
      "color": const Color(0xFF5C6BC0), 
      "icon": Icons.grid_on_rounded
    },
    {
      "name": "Pedodonti", 
      "color": const Color(0xFFFFCA28), 
      "icon": Icons.child_care_rounded
    },
    {
      "name": "Cerrahi", 
      "color": const Color(0xFFB71C1C), 
      "icon": Icons.medical_services_rounded
    },
    {
      "name": "Radyoloji", 
      "color": const Color(0xFF78909C), 
      "icon": Icons.camera_alt_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    List<String> downloaded = await OfflineService.getDownloadedTopics();
    int pending = await OfflineService.getPendingCount();
    
    if (mounted) {
      setState(() {
        _downloadedTopics = downloaded;
        _pendingCount = pending;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadTopic(String topicName) async {
    String cleanTopic = topicName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text("$cleanTopic indiriliyor...")),
          ],
        ),
      ),
    );

    bool success = await OfflineService.downloadTopic(cleanTopic);
    
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
            ? "$cleanTopic başarıyla indirildi." 
            : "İndirme başarısız oldu."),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      if (success) _loadData();
    }
  }

  Future<void> _deleteTopic(String topicName) async {
    String cleanTopic = topicName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Çevrimdışı Veriyi Sil"),
        content: Text("$cleanTopic verisi silinecek. Emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await OfflineService.deleteTopic(cleanTopic);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$cleanTopic silindi.")),
        );
        _loadData();
      }
    }
  }

  Future<void> _syncData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text("Senkronize ediliyor...")),
          ],
        ),
      ),
    );

    await OfflineService.syncPendingData();
    
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veriler senkronize edildi."),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Profil Ekranı ile Aynı Arka Plan
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

    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

    // DİNAMİK PADDING HESABI (Listenin AppBar'ın altında kalmaması için)
    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top + 20;

    return Scaffold(
      extendBodyBehindAppBar: true, // 🔥 Arka planı en üste taşıdık
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        title: Text("Offline Mod", 
          style: GoogleFonts.inter(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        // 🔥 Profil sayfasındaki gibi AppBar Blur Efekti
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
          background, // Arka plan
          
          _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  // 🔥 Padding'i güncelledik
                  padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
                  children: [
                    // Senkronizasyon Kartı
                    if (_pendingCount > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.orange, Colors.deepOrange],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.sync, color: Colors.white, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Senkronize Edilmemiş Veri",
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "$_pendingCount",
                                    style: GoogleFonts.robotoMono(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _syncData,
                                icon: const Icon(Icons.cloud_upload),
                                label: const Text("Şimdi Senkronize Et"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.deepOrange,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Açıklama
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Konuları indirerek internet olmadan çözebilirsiniz. Yanlışlar ve sonuçlar internet bağlantısı sağlandığında otomatik senkronize edilir.",
                              style: GoogleFonts.inter(
                                color: Colors.blue.shade900,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    Text(
                      "Tüm Konular",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Konu Listesi
                    ..._allTopics.map((topic) {
                      String topicName = topic['name'];
                      String cleanName = topicName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                      bool isDownloaded = _downloadedTopics.contains(cleanName);
                      Color themeColor = topic['color'];
                      IconData topicIcon = topic['icon'];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDownloaded 
                              ? Colors.green.withOpacity(0.4) 
                              : (isDark ? Colors.white10 : Colors.transparent),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              topicIcon,
                              color: themeColor,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            topicName,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          subtitle: isDownloaded
                            ? FutureBuilder<String>(
                                future: OfflineService.getTopicSize(cleanName),
                                builder: (context, snapshot) {
                                  return Row(
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        "İndirildi • ${snapshot.data ?? '...'}",
                                        style: GoogleFonts.inter(
                                          color: Colors.green,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : Text(
                                "Çevrimdışı erişim için indir",
                                style: GoogleFonts.inter(
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                          trailing: isDownloaded
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _deleteTopic(topicName),
                              )
                            : ElevatedButton.icon(
                                onPressed: () => _downloadTopic(topicName),
                                icon: const Icon(Icons.download, size: 18),
                                label: const Text("İndir"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}