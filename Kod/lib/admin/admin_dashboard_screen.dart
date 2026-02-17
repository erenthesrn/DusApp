import 'package:flutter/material.dart';
import 'admin_repository.dart';
// Yeni oluşturduğumuz tab dosyalarını import ediyoruz
import 'tabs/question_upload_tab.dart'; 
import 'tabs/user_management_tab.dart';
import 'tabs/reports_tab.dart';


// ─────────────────────────────────────────────────────────────────────────────
// ADMIN GUARD (Aynen koruyoruz - Güvenlik İçin)
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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final bool isAdmin = snapshot.data ?? false;

        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetkisiz Giriş!'), backgroundColor: Colors.red));
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return widget.child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD (ARTIK SADECE SEKMELERİ YÖNETİYOR)
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3, // Toplam sekme sayısı
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          title: const Text('⚙️ Admin Paneli', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.upload_file), text: "Soru Yükle"),
              Tab(icon: Icon(Icons.people), text: "Kullanıcılar"),
              Tab(icon: Icon(Icons.bug_report), text: "Bildirimler"), 
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QuestionUploadTab(), // 1. Sekme: Eski yükleme ekranı
            UserManagementTab(), // 2. Sekme: Yeni kullanıcı listesi
            ReportsTab(),
          ],
        ),
      ),
    );
  }
}