// lib/screens/profile_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_provider.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';
import 'achievements_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = "Yükleniyor...";
  String _email = "";
  String _role = "free";
  int _streak = 0;
  bool _isLoading = true;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // ─── Renk Sabitleri ───────────────────────────────────────────────────────
  static const _darkBg       = Color(0xFF0D1117);
  static const _darkCard     = Color(0xFF161B22);
  static const _darkBorder   = Color(0xFF30363D);
  static const _darkPrimary  = Color(0xFF1E6FBF);
  static const _darkText     = Color(0xFFE6EDF3);
  static const _darkSubText  = Color(0xFF8B949E);

  @override
  void initState() {
    super.initState();
    _listenUserData();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // ─── Firebase ────────────────────────────────────────────────────────────
  void _listenUserData() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          if (mounted) {
            setState(() {
              final data = snapshot.data() as Map<String, dynamic>;
              _name   = data['name']   ?? "İsimsiz";
              _email  = data['email']  ?? currentUser.email!;
              _role   = data['role']   ?? "free";
              _streak = data['streak'] ?? 0;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _name      = currentUser.displayName ?? "Kullanıcı";
              _email     = currentUser.email ?? "";
              _role      = "free";
              _isLoading = false;
            });
            FirebaseFirestore.instance.collection('users').doc(currentUser.uid).set({
              'name': _name, 'email': _email, 'role': 'free',
              'createdAt': FieldValue.serverTimestamp(), 'streak': 0,
            });
          }
        }
      }, onError: (e) {
        debugPrint("Veri dinleme hatası: $e");
        if (mounted) setState(() { _name = "Hata"; _isLoading = false; });
      });
    } else {
      if (mounted) setState(() { _name = "Misafir"; _email = ""; _isLoading = false; });
    }
  }

  // ─── Çıkış ───────────────────────────────────────────────────────────────
  void _signOut() async {
    final isDark = ThemeProvider.instance.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        isDark: isDark,
        title: "Çıkış Yap",
        icon: Icons.logout_rounded,
        iconColor: Colors.red,
        content: const Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          _dialogTextButton(context, "İptal", isDark),
          _dialogActionButton(
            label: "Çıkış Yap",
            color: Colors.red,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Hata Bildir ─────────────────────────────────────────────────────────
  void _showReportDialog() {
    final isDark = ThemeProvider.instance.isDarkMode;
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        isDark: isDark,
        title: "Hata / Öneri Bildir",
        icon: Icons.bug_report_rounded,
        iconColor: Colors.red,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Karşılaştığın sorunu veya önerini paylaş.",
              style: TextStyle(fontSize: 13, color: isDark ? _darkSubText : Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteController,
              maxLines: 4,
              style: TextStyle(color: isDark ? _darkText : Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Örn: Profil resmim güncellenmiyor...",
                hintStyle: TextStyle(color: isDark ? _darkSubText : Colors.grey),
                filled: true,
                fillColor: isDark ? _darkBg : Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? _darkBorder : Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? _darkBorder : Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _darkPrimary),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          _dialogTextButton(context, "Vazgeç", isDark),
          _dialogActionButton(
            label: "Gönder",
            color: _darkPrimary,
            onTap: () async {
              if (noteController.text.trim().isEmpty) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Geri bildiriminiz alındı! Teşekkürler.")),
              );
              try {
                await FirebaseFirestore.instance.collection('app_reports').add({
                  'reportType': 'General / Profile',
                  'userNote': noteController.text.trim(),
                  'userId': FirebaseAuth.instance.currentUser?.uid ?? "Anonim",
                  'userEmail': _email, 'userName': _name,
                  'reportedAt': FieldValue.serverTimestamp(),
                  'status': 'open', 'deviceInfo': 'Android/iOS',
                });
              } catch (e) { debugPrint("Rapor gönderilemedi: $e"); }
            },
          ),
        ],
      ),
    );
  }

  // ─── Hedef Menüsü ────────────────────────────────────────────────────────
  void _showTargetOptions() {
    final isDark = ThemeProvider.instance.isDarkMode;
    _showStyledBottomSheet(
      title: "Hedeflerim",
      icon: Icons.ads_click_rounded,
      iconColor: Colors.teal,
      isDark: isDark,
      items: [
        _SheetItem(
          icon: Icons.timer_outlined,
          iconColor: Colors.orange,
          title: "Günlük Çalışma Süresi",
          subtitle: "Dakika hedefini belirle",
          onTap: () { Navigator.pop(context); _changeDailyGoal(); },
        ),
        _SheetItem(
          icon: Icons.quiz_outlined,
          iconColor: Colors.purple,
          title: "Günlük Soru Hedefi",
          subtitle: "Çözülecek soru sayısını belirle",
          onTap: () { Navigator.pop(context); _changeDailyQuestionGoal(); },
        ),
        _SheetItem(
          icon: Icons.school_outlined,
          iconColor: Colors.blue,
          title: "Uzmanlık Hedefi",
          subtitle: "Bölüm tercihini değiştir",
          onTap: () { Navigator.pop(context); _changeTargetBranch(); },
        ),
      ],
    );
  }

  // ─── İstatistik Ayarları ─────────────────────────────────────────────────
  void _showStatisticsOptions() {
    final isDark = ThemeProvider.instance.isDarkMode;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StatsSheet(isDark: isDark, email: _email),
    );
  }

  // ─── Günlük Süre ─────────────────────────────────────────────────────────
  void _changeDailyGoal() {
    final isDark = ThemeProvider.instance.isDarkMode;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        isDark: isDark,
        title: "Günlük Süre Hedefi",
        icon: Icons.timer_outlined,
        iconColor: Colors.orange,
        content: _goalInputField(ctrl, "Dakika", "Örn: 120", "dk", isDark),
        actions: [
          _dialogTextButton(context, "İptal", isDark),
          _dialogActionButton(
            label: "Kaydet",
            color: Colors.orange,
            onTap: () async {
              final min = int.tryParse(ctrl.text);
              if (min != null && min > 0) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid)
                      .update({'dailyGoalMinutes': min});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Günlük hedef $min dk olarak güncellendi! 🔥")));
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Günlük Soru ─────────────────────────────────────────────────────────
  void _changeDailyQuestionGoal() {
    final isDark = ThemeProvider.instance.isDarkMode;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        isDark: isDark,
        title: "Günlük Soru Hedefi",
        icon: Icons.quiz_outlined,
        iconColor: Colors.purple,
        content: _goalInputField(ctrl, "Soru Sayısı", "Örn: 50", "adet", isDark),
        actions: [
          _dialogTextButton(context, "İptal", isDark),
          _dialogActionButton(
            label: "Kaydet",
            color: Colors.purple,
            onTap: () async {
              final q = int.tryParse(ctrl.text);
              if (q != null && q > 0) {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid)
                      .update({'dailyQuestionGoal': q});
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Günlük hedef $q soru olarak güncellendi! 🚀")));
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ─── Uzmanlık Alanı ──────────────────────────────────────────────────────
  void _changeTargetBranch() {
    final isDark = ThemeProvider.instance.isDarkMode;
    final branches = ["Cerrahi", "Radyoloji", "Pedodonti", "Periodontoloji",
                      "Protez", "Endodonti", "Restoratif", "Ortodonti"];
    final colors   = [Colors.red, Colors.indigo, Colors.pink, Colors.teal,
                      Colors.amber, Colors.cyan, Colors.deepOrange, Colors.purple];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _styledSheet(
          isDark: isDark,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sheetHeader("Uzmanlık Hedefi", Icons.school_outlined, Colors.blue, isDark),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 3.2,
                ),
                itemCount: branches.length,
                itemBuilder: (_, i) {
                  final color = colors[i % colors.length];
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance.collection('users')
                            .doc(user.uid).update({'targetBranch': branches[i]});
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("${branches[i]} hedef olarak seçildi!")));
                          _listenUserData();
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        branches[i],
                        style: TextStyle(
                          color: isDark ? color.withOpacity(0.9) : color.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _toggleSuccessRateVisibility(bool currentValue) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid)
          .update({'showSuccessRate': !currentValue});
    }
  }

  void _resetStatistics(BuildContext ctx) async {
    final isDark = ThemeProvider.instance.isDarkMode;
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (context) => _styledDialog(
        isDark: isDark,
        title: "Emin misin?",
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red,
        content: Text(
          "Tüm çözülen soru sayıları ve başarı oranların sıfırlanacak. Bu işlem geri alınamaz.",
          style: TextStyle(color: isDark ? _darkSubText : Colors.grey[700], fontSize: 13),
        ),
        actions: [
          _dialogTextButton(context, "İptal", isDark),
          _dialogActionButton(
            label: "Sıfırla",
            color: Colors.red,
            onTap: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .update({'totalSolved': 0, 'totalCorrect': 0});
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text("İstatistikler sıfırlandı! 🚀")));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.instance;
    final isDarkMode = themeProvider.isDarkMode;
    final theme = Theme.of(context);

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
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Profilim", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: isDarkMode ? Colors.amber : Colors.indigo
            ),
            onPressed: () => themeProvider.toggleTheme(!isDarkMode)
          )
        ],
      ),
      body: Stack(
        children: [
          background,
          _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  children: [
                    // 1. Kimlik Kartı
                    _buildGlassContainer(
                      isDark: isDarkMode,
                      child: _buildProfileContent(theme, isDarkMode),
                    ),

                    const SizedBox(height: 24),

                    // 2. Streak
                    _buildStreakCard(),

                    const SizedBox(height: 24),

                    // 3. Hesap Ayarları
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Hesap Ayarları", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    _buildGlassContainer(
                      isDark: isDarkMode,
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          if (_role == 'admin') ...[
                            _buildMenuItem(theme, Icons.admin_panel_settings_rounded, "Admin Paneli", "Soru yükleme ve sistem yönetimi", isDarkMode, () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
                            }),
                            _buildDivider(isDarkMode),
                          ],

                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode, color: Colors.blue),
                            ),
                            title: Text("Karanlık Mod", style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
                            subtitle: Text(isDarkMode ? "Açık" : "Kapalı", style: TextStyle(color: isDarkMode ? Colors.white60 : Colors.grey)),
                            trailing: Switch(
                              value: isDarkMode,
                              onChanged: (value) => setState(() => themeProvider.toggleTheme(value)),
                              activeColor: const Color(0xFF0D47A1),
                            ),
                          ),
                          _buildDivider(isDarkMode),

                          _buildMenuItem(theme, Icons.person_outline, "Kişisel Bilgilerim", "İsim ve Şifre işlemleri", isDarkMode, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                          }),
                          _buildDivider(isDarkMode),

                          _buildMenuItem(theme, Icons.emoji_events_rounded, "Rozetlerim & Başarılar", "Kupa dolabına göz at", isDarkMode, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen()));
                          }),
                          _buildDivider(isDarkMode),

                          _buildMenuItem(theme, Icons.analytics_outlined, "İstatistik Ayarları", "Başarı oranı ve sıfırlama", isDarkMode, _showStatisticsOptions),
                          _buildDivider(isDarkMode),

                          _buildMenuItem(theme, Icons.ads_click, "Hedeflerim", "Süre ve Branş tercihlerini yönet", isDarkMode, _showTargetOptions),
                          _buildDivider(isDarkMode),

                          _buildMenuItem(theme, Icons.notifications_outlined, "Bildirimler", "Sınav hatırlatmaları", isDarkMode, () {}),
                          _buildDivider(isDarkMode),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. Diğer
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Diğer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white70 : Colors.grey)),
                    ),
                    const SizedBox(height: 12),

                    _buildGlassContainer(
                      isDark: isDarkMode,
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          _buildMenuItem(theme, Icons.bug_report_outlined, "Hata Bildir", "Sorun mu var?", isDarkMode, _showReportDialog),
                          _buildDivider(isDarkMode),
                          _buildMenuItem(theme, Icons.share, "Arkadaşını Davet Et", "Kazan & Kazandır", isDarkMode, () {}),
                          _buildDivider(isDarkMode),
                          _buildMenuItem(theme, Icons.star_outline, "Bizi Değerlendir", "Mağaza puanı ver", isDarkMode, () {}),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // 5. Çıkış
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: Icon(Icons.logout, color: Colors.red[300], size: 20),
                      label: Text(
                        "Hesaptan Çıkış Yap",
                        style: TextStyle(color: Colors.red[300], fontSize: 16, fontWeight: FontWeight.w600)
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text("Versiyon 1.0.0", style: TextStyle(color: isDarkMode ? Colors.white38 : Colors.grey, fontSize: 12)),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  YARDIMCI WIDGET'LAR
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Glass Container ────────────────────────────────────────────────────────
  Widget _buildGlassContainer({required Widget child, required bool isDark, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) {
    if (!isDark) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── Profil İçeriği ─────────────────────────────────────────────────────────
  Widget _buildProfileContent(ThemeData theme, bool isDark) {
    String initials = _name.isNotEmpty ? _name[0].toUpperCase() : "?";
    if (_name.contains(" ")) {
      var parts = _name.split(" ");
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials += parts[1][0].toUpperCase();
      }
    }

    Color textColor = isDark ? Colors.white : Colors.black;
    Color subTextColor = isDark ? Colors.white60 : Colors.grey;

    return Row(
      children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(isDark ? 0.2 : 0.1),
            shape: BoxShape.circle,
            border: isDark ? Border.all(color: theme.primaryColor.withOpacity(0.5)) : null
          ),
          alignment: Alignment.center,
          child: Text(initials, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? theme.primaryColor.withOpacity(0.9) : const Color(0xFF0D47A1))),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 4),
              Text(_email, style: TextStyle(color: subTextColor, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBadge(Icons.school, "DUS", Colors.orange),
                  const SizedBox(width: 8),
                  _role == 'premium'
                      ? _buildBadge(Icons.workspace_premium, "Premium", Colors.purple)
                      : _buildBadge(Icons.person_outline, "Ücretsiz", isDark ? Colors.grey : Colors.blueGrey),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  // ── Streak Kartı ───────────────────────────────────────────────────────────
  Widget _buildStreakCard() {
    bool isActive = _streak > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFFFF8008), const Color(0xFFFFC837)]
              : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isActive
            ? [BoxShadow(color: const Color(0xFFFF8008).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActive ? "🔥 Günlük Seri" : "💤 Seri Başlamadı",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
              ),
              const SizedBox(height: 4),
              Text(
                isActive ? "Harikasın, böyle devam et!" : "Bugün bir test çöz ve ateşi yak!",
                style: const TextStyle(color: Colors.white, fontSize: 12)
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: Text("$_streak", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
          )
        ],
      ),
    );
  }

  // ── Menü Öğesi ─────────────────────────────────────────────────────────────
  Widget _buildMenuItem(ThemeData theme, IconData icon, String title, String subtitle, bool isDark, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8)
        ),
        child: Icon(icon, color: isDark ? theme.primaryColor : Colors.blueGrey),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[500], fontSize: 12)),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white38 : Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : Colors.grey[100], indent: 70);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOG YARDIMCILARI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _styledDialog({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: isDark ? _darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? _darkText : Colors.black87)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DefaultTextStyle(
              style: TextStyle(color: isDark ? _darkSubText : Colors.grey[700], fontSize: 14),
              child: content,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTextButton(BuildContext ctx, String label, bool isDark) {
    return TextButton(
      onPressed: () => Navigator.pop(ctx),
      child: Text(label,
          style: TextStyle(color: isDark ? _darkSubText : Colors.grey[600])),
    );
  }

  Widget _dialogActionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Widget _goalInputField(
    TextEditingController ctrl,
    String label,
    String hint,
    String suffix,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Ne kadar hedefliyorsun?",
            style: TextStyle(
                fontSize: 13, color: isDark ? _darkSubText : Colors.grey[600])),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: isDark ? _darkText : Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            suffixText: suffix,
            labelStyle: TextStyle(color: isDark ? _darkSubText : Colors.grey),
            filled: true,
            fillColor: isDark ? _darkBg : Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: isDark ? _darkBorder : Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _darkPrimary),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOTTOM SHEET YARDIMCILARI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _styledSheet({required bool isDark, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: isDark
            ? const Border(top: BorderSide(color: _darkBorder, width: 1))
            : null,
      ),
      child: child,
    );
  }

  Widget _sheetHeader(String title, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? _darkBorder : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? _darkText : Colors.black87)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? _darkBorder : Colors.grey[100]),
        ],
      ),
    );
  }

  void _showStyledBottomSheet({
    required String title,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required List<_SheetItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _styledSheet(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHeader(title, icon, iconColor, isDark),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: item.iconColor.withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(item.icon, color: item.iconColor, size: 20),
                    ),
                    title: Text(item.title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? _darkText : Colors.black87)),
                    subtitle: Text(item.subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? _darkSubText : Colors.grey[500])),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: isDark ? Colors.white24 : Colors.grey[350]),
                    onTap: item.onTap,
                  ),
                  if (i < items.length - 1)
                    Divider(height: 1,
                        color: isDark ? _darkBorder.withOpacity(0.5) : Colors.grey[100],
                        indent: 68, endIndent: 16),
                ],
              );
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── İstatistik Sheet (ayrı StatefulWidget, StreamBuilder için) ──────────────
class _StatsSheet extends StatelessWidget {
  final bool isDark;
  final String email;
  const _StatsSheet({required this.isDark, required this.email});

  static const _darkCard    = Color(0xFF161B22);
  static const _darkBorder  = Color(0xFF30363D);
  static const _darkText    = Color(0xFFE6EDF3);
  static const _darkSubText = Color(0xFF8B949E);
  static const _darkBg      = Color(0xFF0D1117);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: isDark ? const Border(top: BorderSide(color: _darkBorder)) : null,
      ),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
          }
          final data = snap.data!.data() as Map<String, dynamic>?;
          final isVisible = data?['showSuccessRate'] ?? true;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle + header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? _darkBorder : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.analytics_outlined, color: Colors.green, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text("İstatistik Ayarları",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? _darkText : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: isDark ? _darkBorder : Colors.grey[100]),
                  ],
                ),
              ),

              // Switch Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: Colors.green, size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Başarı Oranını Göster",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDark ? _darkText : Colors.black87)),
                          Text(isVisible ? "Ana ekranda görünür" : "Ana ekranda gizli",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? _darkSubText : Colors.grey[500])),
                        ],
                      ),
                    ),
                    Switch(
                      value: isVisible,
                      onChanged: (_) async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance.collection('users')
                              .doc(user.uid).update({'showSuccessRate': !isVisible});
                        }
                      },
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),

              Divider(height: 1,
                  color: isDark ? _darkBorder.withOpacity(0.5) : Colors.grey[100],
                  indent: 68, endIndent: 16),

              // Sıfırla
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.cleaning_services_rounded, color: Colors.red, size: 20),
                ),
                title: Text("İstatistikleri Sıfırla",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: Colors.red)),
                subtitle: Text("Tüm soru geçmişini temizler",
                    style: TextStyle(
                        fontSize: 12, color: isDark ? _darkSubText : Colors.grey[500])),
                onTap: () {
                  Navigator.pop(context);
                  _resetStats(context);
                },
              ),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  void _resetStats(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? _darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text("Emin misin?",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? _darkText : Colors.black87)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Tüm çözülen soru sayıları ve başarı oranların sıfırlanacak. Bu işlem geri alınamaz.",
                style: TextStyle(
                    fontSize: 13, color: isDark ? _darkSubText : Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text("İptal",
                        style: TextStyle(color: isDark ? _darkSubText : Colors.grey[600])),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Sıfırla", style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;

    if (confirm) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid)
            .update({'totalSolved': 0, 'totalCorrect': 0});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İstatistikler sıfırlandı! 🚀")));
      }
    }
  }
}

// ─── Veri sınıfı ─────────────────────────────────────────────────────────────
class _SheetItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}