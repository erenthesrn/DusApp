// lib/screens/offline_manager_screen.dart

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
      "name": "📚 Anatomi", 
      "color": Color(0xFFFB8C00), 
      "icon": Icons.accessibility_new_rounded
    },
    {
      "name": "🧬 Histoloji", 
      "color": Color(0xFFEC407A), 
      "icon": Icons.biotech_rounded
    },
    {
      "name": "⚡ Fizyoloji", 
      "color": Color(0xFFEF5350), 
      "icon": Icons.monitor_heart_rounded
    },
    {
      "name": "🧪 Biyokimya", 
      "color": Color(0xFFAB47BC), 
      "icon": Icons.science_rounded
    },
    {
      "name": "🦠 Mikrobiyoloji", 
      "color": Color(0xFF66BB6A), 
      "icon": Icons.coronavirus_rounded
    },
    {
      "name": "🔬 Patoloji", 
      "color": Color(0xFF8D6E63), 
      "icon": Icons.health_and_safety_rounded
    },
    {
      "name": "💊 Farmakoloji", 
      "color": Color(0xFF26A69A), 
      "icon": Icons.medication_rounded
    },
    {
      "name": "🧬 Biyoloji", 
      "color": Color(0xFFD4E157), 
      "icon": Icons.fingerprint_rounded
    },
    {
      "name": "🦷 Protetik", 
      "color": Color(0xFF29B6F6), 
      "icon": Icons.sentiment_satisfied_alt_rounded
    },
    {
      "name": "✨ Restoratif", 
      "color": Color(0xFF42A5F5), 
      "icon": Icons.build_circle_rounded
    },
    {
      "name": "🌿 Endodonti", 
      "color": Color(0xFFFFA726), 
      "icon": Icons.flash_on_rounded
    },
    {
      "name": "🌸 Perio", 
      "color": Color(0xFFFF7043), 
      "icon": Icons.layers_rounded
    },
    {
      "name": "🦴 Ortodonti", 
      "color": Color(0xFF5C6BC0), 
      "icon": Icons.grid_on_rounded
    },
    {
      "name": "👶 Pedodonti", 
      "color": Color(0xFFFFCA28), 
      "icon": Icons.child_care_rounded
    },
    {
      "name": "⚕️ Cerrahi", 
      "color": Color(0xFFB71C1C), 
      "icon": Icons.medical_services_rounded
    },
    {
      "name": "📡 Radyoloji", 
      "color": Color(0xFF78909C), 
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
    // Emoji'yi temizle
    String cleanTopic = topicName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
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
            ? "✅ $cleanTopic başarıyla indirildi!" 
            : "❌ İndirme başarısız oldu"),
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
        title: Text("Offline Veriyi Sil?"),
        content: Text("$cleanTopic offline verisi silinecek. Emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true),
            child: Text("Sil"),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await OfflineService.deleteTopic(cleanTopic);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🗑️ $cleanTopic silindi")),
        );
        _loadData();
      }
    }
  }

  Future<void> _syncData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
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
        SnackBar(
          content: Text("✅ Veriler senkronize edildi!"),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? Color(0xFF0F172A) : Color(0xFFF8FAFC);
    final Color cardColor = isDark ? Color(0xFF1E293B) : Colors.white;
    final Color textColor = isDark ? Color(0xFFE2E8F0) : Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("✈️ Offline Mod", 
          style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Senkronizasyon Kartı
                if (_pendingCount > 0) ...[
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange, Colors.deepOrange],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sync, color: Colors.white, size: 28),
                            SizedBox(width: 12),
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
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _syncData,
                            icon: Icon(Icons.cloud_upload),
                            label: Text("Şimdi Senkronize Et"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.deepOrange,
                              padding: EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],

                // Açıklama
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.withOpacity(0.1) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Konuları indirerek internet olmadan çözebilirsin. Yanlışlar ve sonuçlar internet gelince otomatik senkronize edilir.",
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
                
                SizedBox(height: 24),
                
                Text(
                  "Tüm Konular",
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Konu Listesi
                ..._allTopics.map((topic) {
                  String topicName = topic['name'];
                  String cleanName = topicName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
                  bool isDownloaded = _downloadedTopics.contains(cleanName);
                  Color themeColor = topic['color'];
                  IconData topicIcon = topic['icon']; // Yeni eklenen ikon
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 12),
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
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      // Leading kısmı artık dersin logosunu gösteriyor
                      leading: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          topicIcon, // Özel ders ikonu
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
                                  Icon(Icons.check_circle, size: 14, color: Colors.green),
                                  SizedBox(width: 4),
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
                            "İnternetsiz erişim için indir",
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      trailing: isDownloaded
                        ? IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteTopic(topicName),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _downloadTopic(topicName),
                            icon: Icon(Icons.download, size: 18),
                            label: Text("İndir"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
    );
  }
}