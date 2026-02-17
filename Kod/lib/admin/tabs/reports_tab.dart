import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. MODEL: Type Safety (Tip Güvenliği) Artırıldı
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

    // YARDIMCI: Herhangi bir veriyi güvenle String'e çevirir
    String? safeString(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    return AppReport(
      id: doc.id,
      email: safeString(data['userEmail']) ?? 
             safeString(data['email']) ?? 
             'Anonim',
      
      message: safeString(data['userNote']) ??      
               safeString(data['description']) ??   
               safeString(data['message']) ??       
               safeString(data['report']) ??        
               'Mesaj yok',

      type: safeString(data['reportType']) ?? 'Bildirim',
      
      createdAt: (data['reportedAt'] as Timestamp?)?.toDate() ??
                 (data['createdAt'] as Timestamp?)?.toDate() ??
                 (data['timestamp'] as Timestamp?)?.toDate(),
                 
      // 🔥 DÜZELTME BURADA: as String yerine safeString kullandık
      topic: safeString(data['topic']),
      questionId: safeString(data['questionId']),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. EKRAN KODLARI (Aynen Kalıyor)
// ─────────────────────────────────────────────────────────────────────────────
class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _deletingIds = {};

  String _selectedCollection = 'app_reports'; 

  final Map<String, String> _collectionOptions = {
    'app_reports': 'Genel / Profil Hataları',
    'question_reports': 'Soru Bildirimleri',
  };

  Stream<List<AppReport>> _reportsStream() {
    return _firestore
        .collection(_selectedCollection)
        .snapshots()
        .map((snap) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Bildirim silindi.'),
            ]),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(report.id));
    }
  }

  Future<bool> _showDeleteConfirmDialog(AppReport report) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.delete_outline, color: Colors.red),
          SizedBox(width: 10),
          Text('Silinsin mi?'),
        ]),
        content: Text("'${report.message}' bildirimini kalıcı olarak silmek istiyor musunuz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Evet, Sil"),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Filtre
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCollection,
              isExpanded: true,
              icon: const Icon(Icons.filter_alt, color: Color(0xFF1565C0)),
              items: _collectionOptions.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCollection = val);
              },
            ),
          ),
        ),

        // Liste
        Expanded(
          child: StreamBuilder<List<AppReport>>(
            stream: _reportsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (snapshot.hasError) {
                return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Veri hatası: ${snapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))));
              }

              final reports = snapshot.data ?? [];

              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Bu klasör tertemiz! 🎉", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                      Text("(${_collectionOptions[_selectedCollection]})", style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 5, 16, 80),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  return _ReportCard(
                    report: reports[index],
                    isDeleting: _deletingIds.contains(reports[index].id),
                    onDelete: () => _deleteReport(reports[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. UI: Kart Tasarımı
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCard extends StatelessWidget {
  final AppReport report;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.isDeleting,
    required this.onDelete,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'Tarih yok';
    return DateFormat('dd MMM HH:mm', 'tr_TR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isDeleting ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(report.type, style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Text(_formatDate(report.createdAt), style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(report.email, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                ],
              ),
              
              if (report.topic != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.category_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text("Ders: ${report.topic} ${report.questionId != null ? '(ID: ${report.questionId})' : ''}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                ),
              ],
              
              const Divider(height: 20),
              
              Text(report.message, style: const TextStyle(fontSize: 14, height: 1.4)),
              
              const SizedBox(height: 10),
              
              Align(
                alignment: Alignment.centerRight,
                child: isDeleting 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_forever, size: 20, color: Colors.red),
                      label: const Text("Sil", style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
              )
            ],
          ),
        ),
      ),
    );
  }
}