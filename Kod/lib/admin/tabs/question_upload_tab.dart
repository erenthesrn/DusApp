import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../question_uploader.dart'; // import yoluna dikkat

// Mevcut Dashboard'daki kodları buraya izole ettik
class QuestionUploadTab extends StatefulWidget {
  const QuestionUploadTab({super.key});

  @override
  State<QuestionUploadTab> createState() => _QuestionUploadTabState();
}

class _QuestionUploadTabState extends State<QuestionUploadTab> {
  final QuestionUploadService _uploadService = QuestionUploadService();
  
  // DERS LİSTESİ (Senin listenden alındı)
  final List<Map<String, String>> kTopics = [
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

  String _selectedTopic = 'anatomi'; // Varsayılan
  bool _isUploading = false;
  double _progress = 0.0;
  int _uploadedCount = 0;
  int _totalCount = 0;
  String? _selectedFileName;
  String? _filePath;
  Uint8List? _fileBytes;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: kIsWeb,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      setState(() {
        _selectedFileName = file.name;
        _filePath = file.path;
        _fileBytes = file.bytes;
        _progress = 0.0;
        _uploadedCount = 0;
        _totalCount = 0;
      });
    } catch (e) {
      _showErrorSnackBar('Dosya seçme hatası: $e');
    }
  }

  Future<void> _startUpload() async {
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
        result = await _uploadService.uploadFromBytes(
          bytes: _fileBytes!,
          topic: _selectedTopic,
          onProgress: _handleProgress,
        );
      } else if (_filePath != null) {
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  void _showSuccessDialog(int count, String topic) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 10), Text('Başarılı!')]),
        content: Text('$topic dersine ait $count soru yüklendi.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionCard(
            title: 'Soru Yükleme Aracı',
            icon: Icons.upload_file,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedTopic,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Ders Kategorisi',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: kTopics.map((t) => DropdownMenuItem(value: t['key'], child: Text(t['label']!))).toList(),
                  onChanged: _isUploading ? null : (val) => setState(() => _selectedTopic = val!),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: Text(_selectedFileName ?? 'JSON Dosyası Seç'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
                ),
                if (_isUploading) ...[
                  const SizedBox(height: 20),
                  LinearProgressIndicator(value: _progress),
                  Text('$_uploadedCount / $_totalCount Yüklendi'),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _startUpload,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text("Firestore'a Yükle"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16)
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Yardımcı Kart Widget'ı (Private)
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(children: [Icon(icon, color: const Color(0xFF1565C0)), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)))]),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }
}