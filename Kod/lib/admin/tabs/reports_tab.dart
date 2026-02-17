import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class AppReport {
  final String id;
  final String email;
  final String message;
  final DateTime? createdAt;
  final String? topic;
  final String? questionId;
  final String type;

  const AppReport({
    required this.id,
    required this.email,
    required this.message,
    required this.type,
    this.createdAt,
    this.topic,
    this.questionId,
  });

  factory AppReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    String? safe(dynamic v) => v == null ? null : v.toString();

    return AppReport(
      id: doc.id,
      email: safe(data['userEmail']) ?? safe(data['email']) ?? 'Anonim',
      message: safe(data['userNote']) ??
          safe(data['description']) ??
          safe(data['message']) ??
          safe(data['report']) ??
          'Mesaj yok',
      type: safe(data['reportType']) ?? 'Bildirim',
      createdAt: (data['reportedAt'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate(),
      topic: safe(data['topic']),
      questionId: safe(data['questionId']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _deletingIds = {};
  String _selectedCollection = 'app_reports';

  final Map<String, String> _collectionOptions = {
    'app_reports': 'Genel / Profil Hataları',
    'question_reports': 'Soru Bildirimleri',
  };

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

  Stream<List<AppReport>> _reportsStream() {
    return _firestore.collection(_selectedCollection).snapshots().map((snap) {
      final reports = snap.docs.map(AppReport.fromFirestore).toList();
      reports.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
      return reports;
    });
  }

  Future<void> _deleteReport(AppReport report) async {
    final confirmed = await _showDeleteConfirmDialog(report);
    if (!confirmed) return;

    setState(() => _deletingIds.add(report.id));
    try {
      await _firestore.collection(_selectedCollection).doc(report.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Bildirim silindi.'),
          ]),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(report.id));
    }
  }

  Future<bool> _showDeleteConfirmDialog(AppReport report) async {
    final bool isDark = ThemeProvider.instance.isDarkMode;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.delete_outline, color: Colors.red),
              const SizedBox(width: 10),
              Text('Silinsin mi?',
                  style: TextStyle(
                      color: isDark ? const Color(0xFFE6EDF3) : Colors.black87)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'Bu bildirimi kalıcı olarak silmek istiyor musunuz?',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.message.length > 80
                      ? '${report.message.substring(0, 80)}...'
                      : report.message,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Vazgeç',
                      style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black45))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Evet, Sil'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDark = ThemeProvider.instance.isDarkMode;

    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final Color borderColor = isDark ? Colors.white12 : Colors.blue.shade100;
    final Color accentBlue =
        isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);

    return Column(
      children: [
        // ── Koleksiyon Seçici ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCollection,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
              icon: Icon(Icons.filter_alt, color: accentBlue),
              items: _collectionOptions.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: textColor)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCollection = val);
              },
            ),
          ),
        ),

        // ── Liste ─────────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppReport>>(
            stream: _reportsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Veri hatası: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red)),
                  ),
                );
              }

              final reports = snapshot.data ?? [];

              // Boş durum
              if (reports.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mark_email_read_outlined,
                        size: 64,
                        color: isDark ? Colors.white12 : Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text('Bu klasör tertemiz! 🎉',
                        style: TextStyle(
                            fontSize: 16,
                            color: isDark
                                ? Colors.white30
                                : Colors.grey.shade500)),
                    Text('(${_collectionOptions[_selectedCollection]})',
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400)),
                  ]),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                itemCount: reports.length,
                itemBuilder: (_, i) => _ReportCard(
                  report: reports[i],
                  isDark: isDark,
                  isDeleting: _deletingIds.contains(reports[i].id),
                  onDelete: () => _deleteReport(reports[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BİLDİRİM KARTI
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final AppReport report;
  final bool isDark;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.isDark,
    required this.isDeleting,
    required this.onDelete,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tarih yok';
    return DateFormat('dd MMM HH:mm', 'tr_TR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final Color cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final Color textColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;
    final Color subTextColor = isDark ? Colors.white54 : Colors.black54;
    final Color typeChipBg = isDark ? Colors.blue.withOpacity(0.15) : Colors.blue.shade50;
    final Color typeChipText = isDark ? const Color(0xFF64B5F6) : Colors.blue.shade800;
    final Color dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;

    return AnimatedOpacity(
      opacity: isDeleting ? 0.4 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isDark
              ? Border.all(color: Colors.white.withOpacity(0.07))
              : Border(
                  left: BorderSide(
                      color: const Color(0xFF1565C0).withOpacity(0.4),
                      width: 3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Üst satır: tür rozeti + tarih ──────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: typeChipBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(report.type,
                      style: TextStyle(
                          color: typeChipText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
                Text(_formatDate(report.createdAt),
                    style: TextStyle(
                        color: isDark ? Colors.white30 : Colors.grey.shade400,
                        fontSize: 11)),
              ],
            ),
            const SizedBox(height: 12),

            // ── E-posta ────────────────────────────────────────────────
            Row(children: [
              Icon(Icons.person_outline, size: 16,
                  color: isDark ? Colors.white38 : Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(report.email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: textColor)),
              ),
            ]),

            // ── Konu (varsa) ───────────────────────────────────────────
            if (report.topic != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.category_outlined, size: 16,
                    color: isDark ? Colors.white38 : Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Ders: ${report.topic}'
                  '${report.questionId != null ? ' (ID: ${report.questionId})' : ''}',
                  style: TextStyle(color: subTextColor, fontSize: 13),
                ),
              ]),
            ],

            Divider(height: 20, color: dividerColor),

            // ── Mesaj ──────────────────────────────────────────────────
            Text(report.message,
                style: TextStyle(
                    fontSize: 14, height: 1.4, color: textColor)),
            const SizedBox(height: 10),

            // ── Sil butonu ─────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: isDeleting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_forever,
                          size: 18, color: Colors.red),
                      label: const Text('Sil',
                          style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            Colors.red.withOpacity(isDark ? 0.1 : 0.05),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
