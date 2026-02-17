import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_repository.dart';
import 'question_uploader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DERS LİSTESİ
// QuestionUploader'daki dosya isimleriyle eşleştirildi.
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, String>> kTopics = [
  {'key': 'anatomi', 'label': 'Anatomi'},
  {'key': 'biyokimya', 'label': 'Biyokimya'},
  {'key': 'fizyoloji', 'label': 'Fizyoloji'},
  {'key': 'histoloji', 'label': 'Histoloji'},
  {'key': 'farma', 'label': 'Farmakoloji'},
  {'key': 'patoloji', 'label': 'Patoloji'},
  {'key': 'mikrobiyoloji', 'label': 'Mikrobiyoloji'},
  {'key': 'biyoloji', 'label': 'Biyoloji'},
  {'key': 'cerrahi', 'label': 'Cerrahi'},
  {'key': 'endo', 'label': 'Endodonti'},
  {'key': 'perio', 'label': 'Periodontoloji'},
  {'key': 'orto', 'label': 'Ortodonti'},
  {'key': 'pedo', 'label': 'Pedodonti'},
  {'key': 'protetik', 'label': 'Protetik'},
  {'key': 'radyoloji', 'label': 'Radyoloji'},
  {'key': 'resto', 'label': 'Restoratif'},
];

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN GUARD — Admin olmayan kullanıcıyı otomatik yönlendirir
// Kullanım: Navigator.push(context, MaterialPageRoute(
//   builder: (_) => const AdminGuard(child: AdminDashboardScreen())))
// ─────────────────────────────────────────────────────────────────────────────
class AdminGuard extends StatefulWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  final AdminRepository _adminRepo = AdminRepository();
  late Future<bool> _adminCheck;

  @override
  void initState() {
    super.initState();
    _adminCheck = _adminRepo.checkAdminStatus();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminCheck,
      builder: (context, snapshot) {
        // Kontrol devam ediyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bool isAdmin = snapshot.data ?? false;

        if (!isAdmin) {
          // Admin değil → bir sonraki frame'de ana sayfaya yönlendir
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '🚫 Bu sayfaya erişim yetkiniz yok.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Ana sayfaya geri dön (tüm stack temizlenerek)
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });

          // Yönlendirme olana kadar boş ekran göster
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Admin → asıl sayfayı göster
        return widget.child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final QuestionUploadService _uploadService = QuestionUploadService();

  // Seçili ders
  String _selectedTopic = kTopics.first['key']!;

  // UI state
  bool _isUploading = false;
  double _progress = 0.0;
  int _uploadedCount = 0;
  int _totalCount = 0;
  String? _selectedFileName;

  // Seçilen dosya (platform'a göre path veya bytes)
  String? _filePath; // Mobile / Desktop
  Uint8List? _fileBytes; // Web

  // ─────────────────────────────────────────────────────────────────────────
  // 1. DOSYA SEÇİCİ
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb, // Web'de bytes gerekli
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      setState(() {
        _selectedFileName = file.name;
        _filePath = file.path; // null on web
        _fileBytes = file.bytes; // null on non-web
        _progress = 0.0;
        _uploadedCount = 0;
        _totalCount = 0;
      });
    } catch (e) {
      _showErrorSnackBar('Dosya seçme hatası: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. YÜKLEME BAŞLAT
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _startUpload() async {
    // Dosya seçilmemiş
    if (_filePath == null && _fileBytes == null) {
      _showErrorSnackBar('Lütfen önce bir JSON dosyası seçin.');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0.0;
    });

    UploadResult result;

    try {
      if (kIsWeb && _fileBytes != null) {
        // Web modu
        result = await _uploadService.uploadFromBytes(
          bytes: _fileBytes!,
          topic: _selectedTopic,
          onProgress: _handleProgress,
        );
      } else if (_filePath != null) {
        // Mobile / Desktop modu
        result = await _uploadService.uploadFromFile(
          filePath: _filePath!,
          topic: _selectedTopic,
          onProgress: _handleProgress,
        );
      } else {
        result = UploadResult.error('Geçersiz dosya.');
      }
    } catch (e) {
      result = UploadResult.error('Beklenmeyen hata: $e');
    }

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (result.isSuccess) {
      _showSuccessDialog(result.uploadedCount, result.topic);
      // Seçili dosyayı sıfırla
      setState(() {
        _selectedFileName = null;
        _filePath = null;
        _fileBytes = null;
      });
    } else {
      _showErrorSnackBar(result.errorMessage ?? 'Bilinmeyen hata.');
    }
  }

  void _handleProgress(double progress, int uploaded, int total) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _uploadedCount = uploaded;
      _totalCount = total;
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UI YARDIMCILARI
  // ─────────────────────────────────────────────────────────────────────────
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessDialog(int count, String topic) {
    final label = kTopics
        .firstWhere(
          (t) => t['key'] == topic,
          orElse: () => {'label': topic},
        )['label']!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Yükleme Başarılı!'),
          ],
        ),
        content: Text(
          '$label dersine ait $count soru Firestore\'a başarıyla yüklendi.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text(
          '⚙️ Admin Paneli',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Başlık Kartı ──────────────────────────────────────────────
            _SectionCard(
              title: 'Soru Yükleme Aracı',
              icon: Icons.upload_file,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Bir JSON dosyası seçin, ders kategorisini belirleyin ve '
                    'Firestore\'a toplu yükleyin.',
                    style: TextStyle(color: Colors.black54, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // ── Ders Seçici ───────────────────────────────────────
                  const Text(
                    'Ders Kategorisi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTopic,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    items: kTopics
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['key'],
                            child: Text(t['label']!),
                          ),
                        )
                        .toList(),
                    onChanged: _isUploading
                        ? null // Yükleme sırasında değişim engelle
                        : (val) {
                            if (val != null) {
                              setState(() => _selectedTopic = val);
                            }
                          },
                  ),

                  const SizedBox(height: 20),

                  // ── Dosya Seçici Butonu ───────────────────────────────
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFile,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                          color: Color(0xFF1565C0), width: 1.5),
                    ),
                    icon: const Icon(Icons.folder_open,
                        color: Color(0xFF1565C0)),
                    label: Text(
                      _selectedFileName ?? 'JSON Dosyası Seç',
                      style: TextStyle(
                        color: _selectedFileName != null
                            ? Colors.black87
                            : const Color(0xFF1565C0),
                        fontWeight: _selectedFileName != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),

                  // Dosya seçildiyse küçük bilgi satırı
                  if (_selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _selectedFileName!,
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Progress Indicator ────────────────────────────────
                  if (_isUploading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Yükleniyor... $_uploadedCount / $_totalCount',
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '%${(_progress * 100).toInt()}',
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 10,
                        backgroundColor: Colors.blue.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1565C0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Yükle Butonu ─────────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _startUpload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor:
                          const Color(0xFF1565C0).withOpacity(0.4),
                    ),
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _isUploading ? 'Yükleniyor...' : 'Firestore\'a Yükle',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── JSON Format Bilgisi ──────────────────────────────────────
            _SectionCard(
              title: 'Beklenen JSON Formatı',
              icon: Icons.code,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SelectableText(
                  '[\n'
                  '  {\n'
                  '    "id": 1,\n'
                  '    "test_no": 1,\n'
                  '    "level": "Kolay",\n'
                  '    "question": "Soru metni buraya...",\n'
                  '    "options": [\n'
                  '      "A) Seçenek 1",\n'
                  '      "B) Seçenek 2",\n'
                  '      "C) Seçenek 3",\n'
                  '      "D) Seçenek 4",\n'
                  '      "E) Seçenek 5"\n'
                  '    ],\n'
                  '    "answer_index": 2,\n'
                  '    "explanation": "Açıklama metni..."\n'
                  '  }\n'
                  ']',
                  style: TextStyle(
                    color: Color(0xFF79C0FF),
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Uyarı Kartı ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yükleme işlemi mevcut soruların üzerine yazar (merge: true). '
                      'Silme işlemi yapmaz. '
                      'Büyük dosyalar için 500 limit aşımını önlemek adına '
                      'otomatik batch bölünmesi yapılır.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YARDIMCI WİDGET: Kart bileşeni
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF1565C0), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}
