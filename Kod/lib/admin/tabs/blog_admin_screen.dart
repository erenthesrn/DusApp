import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =============================================================================
// BLOG ADMİN PANEL
// =============================================================================
// Kullanım: Herhangi bir yerden şöyle aç:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const BlogAdminScreen()));
//
// Firebase Yapısı (blog_posts koleksiyonu):
//   title       : String   — Yazı başlığı
//   category    : String   — Rehberlik | Ders Taktikleri | Haberler | Motivasyon
//   imageUrl    : String   — Görsel URL (opsiyonel)
//   publishedAt : Timestamp — Yayın tarihi
//   readTime    : String   — "5 dk" formatında okuma süresi
// =============================================================================


// =============================================================================
// ROL KONTROLÜ — Yardımcı Fonksiyon
// =============================================================================
// Firestore yapısı: users/{uid} → { role: "admin", ... }
// Admin rolü vermek için Firebase Console'da:
//   Firestore → users → {kullanıcının UID'si} → role alanını "admin" yap

Future<bool> _isCurrentUserAdmin() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data()?['role'] == 'admin';
  } catch (_) {
    return false;
  }
}

// =============================================================================
// ADMIN GUARD — Sarmalayıcı Widget
// =============================================================================
// Bu widget'ı kullanarak herhangi bir ekranı rol kontrolüne bağlayabilirsin:
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminGuard(child: BlogAdminScreen())));

class AdminGuard extends StatelessWidget {
  final Widget child;
  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<bool>(
      future: _isCurrentUserAdmin(),
      builder: (context, snapshot) {
        // Kontrol devam ediyor
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF090A0F) : const Color(0xFFF2F4F8),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        // Admin değil veya giriş yapılmamış
        if (snapshot.data != true) {
          return _AccessDeniedScreen(isDark: isDark);
        }
        // Admin — içeriği göster
        return child;
      },
    );
  }
}

// =============================================================================
// ERİŞİM ENGELLENDİ EKRANI
// =============================================================================
class _AccessDeniedScreen extends StatelessWidget {
  final bool isDark;
  const _AccessDeniedScreen({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090A0F) : const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 56, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              Text(
                "Erişim Engellendi",
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Bu sayfaya erişmek için admin yetkisi gerekiyor.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, height: 1.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    "Geri Dön",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BlogAdminScreen extends StatefulWidget {
  const BlogAdminScreen({super.key});

  @override
  State<BlogAdminScreen> createState() => _BlogAdminScreenState();
}

class _BlogAdminScreenState extends State<BlogAdminScreen> {
  final _col = FirebaseFirestore.instance.collection('blog_posts');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF090A0F) : const Color(0xFFF2F4F8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        elevation: 0,
        title: Text(
          "Blog Yönetimi",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Yeni yazı ekle butonu
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _openForm(context, isDark, null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text("Yeni Yazı",
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _col.orderBy('publishedAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text("Hata: ${snapshot.error}",
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
              ]),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.article_outlined, size: 72,
                    color: isDark ? Colors.white12 : Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("Henüz yazı yok.",
                    style: TextStyle(fontSize: 16,
                        color: isDark ? Colors.grey[500] : Colors.grey[600])),
                const SizedBox(height: 8),
                Text("Sağ üstteki butona basarak ilk yazını ekle.",
                    style: TextStyle(fontSize: 13,
                        color: isDark ? Colors.grey[600] : Colors.grey[500])),
              ]),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final publishedAt = (data['publishedAt'] as Timestamp?)?.toDate();

              return _AdminPostCard(
                docId: doc.id,
                title: data['title'] ?? 'Başlıksız',
                category: data['category'] ?? 'Genel',
                imageUrl: data['imageUrl'] ?? '',
                readTime: data['readTime'] ?? '3 dk',
                publishedAt: publishedAt,
                isDark: isDark,
                onEdit: () => _openForm(context, isDark, doc),
                onDelete: () => _confirmDelete(context, isDark, doc.id, data['title'] ?? 'bu yazı'),
              );
            },
          );
        },
      ),
    );
  }

  // ── Silme onayı ─────────────────────────────────────────────────────────────
  void _confirmDelete(BuildContext ctx, bool isDark, String docId, String title) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Yazıyı Sil",
            style: TextStyle(fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          '"$title" yazısını silmek istediğinden emin misin? Bu işlem geri alınamaz.',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text("İptal",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _col.doc(docId).delete();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: const Text("Yazı silindi."),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Form aç (yeni ekle veya düzenle) ───────────────────────────────────────
  void _openForm(BuildContext ctx, bool isDark, DocumentSnapshot? existing) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BlogPostForm(
        isDark: isDark,
        existing: existing,
        onSave: (data) async {
          if (existing != null) {
            await _col.doc(existing.id).update(data);
          } else {
            await _col.add(data);
          }
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(existing != null ? "Yazı güncellendi." : "Yeni yazı eklendi!"),
                backgroundColor: const Color(0xFF34C759),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
      ),
    );
  }
}

// =============================================================================
// ADMİN POST KARTI
// =============================================================================
class _AdminPostCard extends StatelessWidget {
  final String docId, title, category, imageUrl, readTime;
  final DateTime? publishedAt;
  final bool isDark;
  final VoidCallback onEdit, onDelete;

  const _AdminPostCard({
    required this.docId, required this.title, required this.category,
    required this.imageUrl, required this.readTime, required this.publishedAt,
    required this.isDark, required this.onEdit, required this.onDelete,
  });

  Color _catColor() {
    switch (category) {
      case "Rehberlik": return const Color(0xFF0969DA);
      case "Ders Taktikleri": return const Color(0xFF8A2BE2);
      case "Haberler": return const Color(0xFFFF9500);
      case "Motivasyon": return const Color(0xFF34C759);
      default: return const Color(0xFF0969DA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final catColor = _catColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Resim küçük önizleme
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            child: SizedBox(
              width: 80, height: 80,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(catColor))
                  : _placeholder(catColor),
            ),
          ),
          const SizedBox(width: 12),
          // Bilgiler
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(category,
                        style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  Text(title,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 11,
                        color: isDark ? Colors.grey[600] : Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(readTime,
                        style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.grey[600] : Colors.grey[500])),
                    if (publishedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "${publishedAt!.day}.${publishedAt!.month}.${publishedAt!.year}",
                        style: TextStyle(fontSize: 11,
                            color: isDark ? Colors.grey[600] : Colors.grey[500]),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          // Aksiyonlar
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_rounded,
                    color: isDark ? const Color(0xFF448AFF) : Colors.blue, size: 20),
                tooltip: "Düzenle",
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 20),
                tooltip: "Sil",
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _placeholder(Color color) => Container(
    color: color.withOpacity(0.1),
    child: Center(child: Icon(Icons.image_outlined, color: color.withOpacity(0.3), size: 24)),
  );
}

// =============================================================================
// BLOG YAZISI FORMU (Ekle / Düzenle)
// =============================================================================
class _BlogPostForm extends StatefulWidget {
  final bool isDark;
  final DocumentSnapshot? existing;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _BlogPostForm({
    required this.isDark, required this.existing, required this.onSave,
  });

  @override
  State<_BlogPostForm> createState() => _BlogPostFormState();
}

class _BlogPostFormState extends State<_BlogPostForm> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  late final TextEditingController _readTime;
  late final TextEditingController _content;

  String _category = "Rehberlik";
  DateTime _publishedAt = DateTime.now();

  final List<String> _categories = [
    "Rehberlik", "Ders Taktikleri", "Haberler", "Motivasyon"
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.existing?.data() as Map<String, dynamic>?;
    _title    = TextEditingController(text: d?['title'] ?? '');
    _imageUrl = TextEditingController(text: d?['imageUrl'] ?? '');
    _readTime = TextEditingController(text: d?['readTime'] ?? '5 dk');
    _content  = TextEditingController(text: d?['content'] ?? '');
    _category = d?['category'] ?? 'Rehberlik';
    _publishedAt = (d?['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose(); _imageUrl.dispose(); _readTime.dispose(); _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      await widget.onSave({
        'title':       _title.text.trim(),
        'category':    _category,
        'imageUrl':    _imageUrl.text.trim(),
        'readTime':    _readTime.text.trim(),
        'content':     _content.text.trim(),
        'publishedAt': Timestamp.fromDate(_publishedAt),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF0969DA)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _publishedAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg     = isDark ? const Color(0xFF0D1117) : Colors.white;
    final surface = isDark ? const Color(0xFF161B22) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final isEdit = widget.existing != null;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Başlık
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  isEdit ? "Yazıyı Düzenle" : "Yeni Blog Yazısı",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
                ),
              ]),

              const SizedBox(height: 24),

              // Başlık alanı
              _label("Başlık *", subColor),
              const SizedBox(height: 6),
              _field(
                controller: _title,
                hint: "Yazının başlığını gir...",
                surface: surface, textColor: textColor, isDark: isDark,
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty ? "Başlık boş olamaz" : null,
              ),

              const SizedBox(height: 16),

              // Kategori
              _label("Kategori *", subColor),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _categories.map((cat) {
                  final sel = cat == _category;
                  final color = _catColor(cat);
                  return GestureDetector(
                    onTap: () { HapticFeedback.selectionClick(); setState(() => _category = cat); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? color : surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? Colors.transparent : color.withOpacity(0.3)),
                      ),
                      child: Text(cat, style: TextStyle(
                        color: sel ? Colors.white : color,
                        fontSize: 13, fontWeight: FontWeight.w600,
                      )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Görsel URL
              _label("Görsel URL (opsiyonel)", subColor),
              const SizedBox(height: 6),
              _field(
                controller: _imageUrl,
                hint: "https://örnek.com/resim.jpg",
                surface: surface, textColor: textColor, isDark: isDark,
                keyboardType: TextInputType.url,
              ),

              // URL önizleme
              if (_imageUrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 120, width: double.infinity,
                    child: Image.network(
                      _imageUrl.text,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: surface,
                        child: Center(child: Text("Görsel yüklenemedi",
                            style: TextStyle(color: subColor, fontSize: 12))),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // İçerik (yazı metni)
              _label("Yazı İçeriği", subColor),
              const SizedBox(height: 4),
              Text(
                "Desteklenen format: # Başlık  ## Alt Başlık  > Alıntı  - Madde",
                style: TextStyle(fontSize: 11, color: subColor),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _content,
                maxLines: 10,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.6),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "## Giriş\n\nBuraya yazının içeriğini gir...\n\n## Sonuç\n\nYazıyı burada bitir.",
                  hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 13),
                  filled: true, fillColor: surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF0969DA), width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 16),

              // Okuma süresi + Tarih yan yana
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label("Okuma Süresi *", subColor),
                  const SizedBox(height: 6),
                  _field(
                    controller: _readTime,
                    hint: "5 dk",
                    surface: surface, textColor: textColor, isDark: isDark,
                    validator: (v) => v == null || v.trim().isEmpty ? "Boş olamaz" : null,
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _label("Yayın Tarihi *", subColor),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        Icon(Icons.calendar_today_rounded, size: 16,
                            color: const Color(0xFF0969DA)),
                        const SizedBox(width: 8),
                        Text(
                          "${_publishedAt.day}.${_publishedAt.month}.${_publishedAt.year}",
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ]),
                    ),
                  ),
                ])),
              ]),

              const SizedBox(height: 28),

              // Kaydet butonu
              GestureDetector(
                onTap: _saving ? null : _save,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0969DA), Color(0xFF8A2BE2)]),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF0969DA).withOpacity(0.35),
                        blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Center(
                    child: _saving
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(isEdit ? Icons.save_rounded : Icons.cloud_upload_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(isEdit ? "Değişiklikleri Kaydet" : "Firebase'e Yayınla",
                                style: const TextStyle(color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat) {
      case "Rehberlik": return const Color(0xFF0969DA);
      case "Ders Taktikleri": return const Color(0xFF8A2BE2);
      case "Haberler": return const Color(0xFFFF9500);
      case "Motivasyon": return const Color(0xFF34C759);
      default: return const Color(0xFF0969DA);
    }
  }

  Widget _label(String text, Color color) => Text(
    text,
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required Color surface, required Color textColor,
    required bool isDark,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      onChanged: (_) => setState(() {}),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey.shade400, fontSize: 14),
        filled: true, fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0969DA), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
