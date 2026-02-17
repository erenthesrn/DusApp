import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../question_uploader.dart';
import '../../services/theme_provider.dart';

class QuestionUploadTab extends StatefulWidget {
  const QuestionUploadTab({super.key});

  @override
  State<QuestionUploadTab> createState() => _QuestionUploadTabState();
}

class _QuestionUploadTabState extends State<QuestionUploadTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final QuestionUploadService _uploadService = QuestionUploadService();

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

  String _selectedTopic = 'anatomi';
  bool _isUploading = false;
  double _progress = 0.0;
  int _uploadedCount = 0;
  int _totalCount = 0;
  String? _selectedFileName;
  String? _filePath;
  Uint8List? _fileBytes;

  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  // ── Dosya seç ─────────────────────────────────────────────────────────────
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

  // ── Yükleme ───────────────────────────────────────────────────────────────
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
            onProgress: _handleProgress);
      } else if (_filePath != null) {
        result = await _uploadService.uploadFromFile(
            filePath: _filePath!,
            topic: _selectedTopic,
            onProgress: _handleProgress);
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating));
  }

  void _showSuccessDialog(int count, String topic) {
    final bool isDark = ThemeProvider.instance.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            isDark ? const Color(0xFF161B22) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 10),
          Text('Başarılı!',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87)),
        ]),
        content: Text('$topic dersine ait $count soru yüklendi.',
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tamam'))
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDark = ThemeProvider.instance.isDarkMode;

    // Renk değişkenleri
    final Color cardBg =
        isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor =
        isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final Color subTextColor =
        isDark ? Colors.white54 : Colors.black54;
    final Color accentBlue =
        isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    final Color inputFill =
        isDark ? const Color(0xFF0D1117) : Colors.white;
    final Color borderColor =
        isDark ? Colors.white12 : Colors.blue.shade100;
    final Color warningBg =
        isDark ? Colors.orange.withOpacity(0.08) : Colors.orange.shade50;
    final Color warningBorder =
        isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Yükleme Kartı ─────────────────────────────────────────────────
          _DarkCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık
                Row(children: [
                  Icon(Icons.upload_file, color: accentBlue, size: 22),
                  const SizedBox(width: 10),
                  Text('Soru Yükleme Aracı',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: accentBlue)),
                ]),
                Divider(height: 24, color: isDark ? Colors.white12 : null),

                // Ders seçici
                Text('Ders Kategorisi',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentBlue,
                        fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedTopic,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF161B22)
                      : Colors.white,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accentBlue)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  items: kTopics
                      .map((t) => DropdownMenuItem(
                          value: t['key'],
                          child: Text(t['label']!,
                              style: TextStyle(color: textColor))))
                      .toList(),
                  onChanged: _isUploading
                      ? null
                      : (val) => setState(() => _selectedTopic = val!),
                ),
                const SizedBox(height: 16),

                // Dosya seç butonu
                OutlinedButton.icon(
                  onPressed: _isUploading ? null : _pickFile,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    side: BorderSide(color: accentBlue, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.folder_open, color: accentBlue),
                  label: Text(
                    _selectedFileName ?? 'JSON Dosyası Seç',
                    style: TextStyle(
                      color: _selectedFileName != null
                          ? textColor
                          : accentBlue,
                      fontWeight: _selectedFileName != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

                // Seçili dosya onay satırı
                if (_selectedFileName != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(_selectedFileName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.green, fontSize: 12))),
                  ]),
                ],
                const SizedBox(height: 16),

                // Progress
                if (_isUploading) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Yükleniyor... $_uploadedCount / $_totalCount',
                          style: TextStyle(
                              color: accentBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('%${(_progress * 100).toInt()}',
                          style: TextStyle(
                              color: accentBlue,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: isDark
                          ? Colors.white10
                          : Colors.blue.shade100,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(accentBlue),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Yükle butonu
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _startUpload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade300,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: isDark ? 0 : 4,
                    shadowColor: accentBlue.withOpacity(0.4),
                  ),
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _isUploading
                        ? 'Yükleniyor...'
                        : 'Firestore\'a Yükle',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── JSON Format Kartı ─────────────────────────────────────────────
          _DarkCard(
            isDark: isDark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.code, color: accentBlue, size: 22),
                  const SizedBox(width: 10),
                  Text('Beklenen JSON Formatı',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: accentBlue)),
                ]),
                Divider(height: 24, color: isDark ? Colors.white12 : null),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
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
                    '    "question": "Soru metni...",\n'
                    '    "options": ["A) ...", "B) ...", "C) ..."],\n'
                    '    "answer_index": 2,\n'
                    '    "explanation": "Açıklama..."\n'
                    '  }\n'
                    ']',
                    style: TextStyle(
                        color: Color(0xFF79C0FF),
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Uyarı Bandı ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: warningBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: warningBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber,
                    color: Colors.orange.shade400, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Yükleme mevcut soruların üzerine yazar (merge: true). '
                    'Silme yapmaz. 500 limit için otomatik batch bölünmesi uygulanır.',
                    style: TextStyle(
                        color: isDark
                            ? Colors.orange.shade300
                            : Colors.orange.shade900,
                        height: 1.5,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YARDIMCI: Tema Uyumlu Kart
// ─────────────────────────────────────────────────────────────────────────────
class _DarkCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _DarkCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.08))
            : null,
        boxShadow: isDark
            ? [
                BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5))
              ],
      ),
      child: child,
    );
  }
}
