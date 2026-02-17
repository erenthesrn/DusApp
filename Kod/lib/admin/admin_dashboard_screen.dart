import 'package:flutter/material.dart';
import '../services/theme_provider.dart';
import 'admin_repository.dart';
import 'tabs/question_upload_tab.dart';
import 'tabs/user_management_tab.dart';
import 'tabs/reports_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN GUARD
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
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final bool isAdmin = snapshot.data ?? false;

        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Yetkisiz Giriş!'),
                  backgroundColor: Colors.red));
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return widget.child;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ThemeProvider değiştiğinde rebuild için listener
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeProvider.instance.isDarkMode;

    // Renk paleti — QuizScreen ile aynı mantık
    final Color appBarBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFF1565C0);
    final Color scaffoldBg =
        isDark ? const Color(0xFF0A0E14) : const Color(0xFFE3F2FD);
    final Color indicatorColor =
        isDark ? const Color(0xFF64B5F6) : Colors.white;
    final Color labelColor =
        isDark ? const Color(0xFF64B5F6) : Colors.white;
    final Color unselectedColor =
        isDark ? Colors.white38 : Colors.white70;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: isDark ? const Color(0xFFE6EDF3) : Colors.white,
          elevation: isDark ? 0 : 2,
          title: const Text(
            '⚙️ Admin Paneli',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: indicatorColor,
            indicatorWeight: 3,
            labelColor: labelColor,
            unselectedLabelColor: unselectedColor,
            labelStyle: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(icon: Icon(Icons.upload_file, size: 19), text: 'Soru Yükle'),
              Tab(icon: Icon(Icons.people, size: 19), text: 'Kullanıcılar'),
              Tab(icon: Icon(Icons.bug_report, size: 19), text: 'Bildirimler'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            QuestionUploadTab(),
            UserManagementTab(),
            ReportsTab(),
          ],
        ),
      ),
    );
  }
}
