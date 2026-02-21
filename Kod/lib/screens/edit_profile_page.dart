// lib/screens/edit_profile_page.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_provider.dart';
import 'login_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailController.text = user.email ?? "";
      _nameController.text = user.displayName ?? "";
      if (user.displayName == null || user.displayName!.isEmpty) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
          if (doc.exists && mounted) {
            setState(() { _nameController.text = doc['name']; });
          }
        });
      }
    }
  }

  bool _isPasswordStrong(String password) {
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasMinLength = password.length >= 8;
    return hasUppercase && hasDigits && hasMinLength;
  }

  Future<void> _updateName() async {
    if (_nameController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(_nameController.text);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'name': _nameController.text});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İsim güncellendi! ✅")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentPasswordController.text.isEmpty || _newPasswordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tüm şifre alanlarını doldurun.")));
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni şifreler uyuşmuyor! ❌"), backgroundColor: Colors.red));
      return;
    }
    if (!_isPasswordStrong(_newPasswordController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre en az 1 büyük harf ve 1 rakam içermeli! ⚠️"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      AuthCredential credential = EmailAuthProvider.credential(email: user?.email ?? "", password: _currentPasswordController.text);
      await user?.reauthenticateWithCredential(credential);
      await user?.updatePassword(_newPasswordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre başarıyla değiştirildi! 🔒")));
        _currentPasswordController.clear(); _newPasswordController.clear(); _confirmPasswordController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu! Mevcut şifre yanlış olabilir."), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    TextEditingController passwordController = TextEditingController();
    bool isDark = ThemeProvider.instance.isDarkMode;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Hesabı Sil ⚠️", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Lütfen şifrenizi girin:", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black87)),
            const SizedBox(height: 16),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Şifre", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Onayla ve Sil", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirm == true && passwordController.text.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        User? user = FirebaseAuth.instance.currentUser;
        AuthCredential credential = EmailAuthProvider.credential(email: user?.email ?? "", password: passwordController.text);
        await user?.reauthenticateWithCredential(credential);
        await FirebaseFirestore.instance.collection('users').doc(user?.uid).delete();
        await user?.delete();
        if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu!"), backgroundColor: Colors.red));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeProvider.instance.isDarkMode;
    final Color textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1E293B);
    final Color sectionHeaderColor = isDark ? const Color(0xFF448AFF) : const Color(0xFF0D47A1);

    // Cyber Glass Arka Plan Tanımı
    Widget background = isDark
        ? Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0E14), Color(0xFF161B22)],
              ),
            ),
          )
        : Container(color: const Color(0xFFE0F7FA));

    final double topPadding = kToolbarHeight + MediaQuery.of(context).padding.top + 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text("Profili Düzenle", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: (isDark ? const Color(0xFF0D1117) : Colors.white).withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          background,
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 40),
                      child: Column(
                        children: [
                          _buildPremiumAvatar(isDark),
                          const SizedBox(height: 40),
                          _sectionTitle("Kişisel Bilgiler", sectionHeaderColor),
                          const SizedBox(height: 12),
                          _buildGlassCard(
                            isDark: isDark,
                            children: [
                              _buildTextField(controller: _emailController, label: "E-posta", icon: Icons.email_outlined, isReadOnly: true, isDark: isDark),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _nameController, label: "Ad Soyad", icon: Icons.person_outline, isDark: isDark),
                              const SizedBox(height: 20),
                              _buildGradientButton(
                                text: "İsmi Güncelle",
                                onTap: _updateName,
                                colors: isDark ? [const Color(0xFF1E6FBF), const Color(0xFF1565C0)] : [const Color(0xFF42A5F5), const Color(0xFF1565C0)],
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _sectionTitle("Güvenlik & Şifre", sectionHeaderColor),
                          const SizedBox(height: 12),
                          _buildGlassCard(
                            isDark: isDark,
                            children: [
                              _buildTextField(controller: _currentPasswordController, label: "Mevcut Şifre", icon: Icons.lock_outline, isDark: isDark, obscureText: _obscureCurrent, onEyeTap: () => setState(() => _obscureCurrent = !_obscureCurrent)),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _newPasswordController, label: "Yeni Şifre", icon: Icons.vpn_key, isDark: isDark, obscureText: _obscureNew, onEyeTap: () => setState(() => _obscureNew = !_obscureNew), hint: "En az 1 büyük harf ve rakam"),
                              const SizedBox(height: 16),
                              _buildTextField(controller: _confirmPasswordController, label: "Yeni Şifre (Tekrar)", icon: Icons.vpn_key_outlined, isDark: isDark, obscureText: _obscureConfirm, onEyeTap: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                              const SizedBox(height: 20),
                              _buildGradientButton(text: "Şifreyi Değiştir", onTap: _changePassword, colors: [const Color(0xFFFF9800), const Color(0xFFF57C00)]),
                            ],
                          ),
                          const SizedBox(height: 50),
                          _buildDeleteButton(),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // --- Widget Yardımcıları ---

  Widget _sectionTitle(String title, Color color) {
    return Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)));
  }

  Widget _buildPremiumAvatar(bool isDark) {
    String initials = _nameController.text.isNotEmpty ? _nameController.text.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase() : "U";
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border.all(color: isDark ? const Color(0xFF448AFF).withOpacity(0.5) : const Color(0xFF0D47A1).withOpacity(0.2), width: 2),
        boxShadow: [BoxShadow(color: isDark ? const Color(0xFF448AFF).withOpacity(0.3) : Colors.blue.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Center(child: Text(initials, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF448AFF) : const Color(0xFF0D47A1)))),
    );
  }

  Widget _buildGlassCard({required List<Widget> children, required bool isDark}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22).withOpacity(0.7) : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.white, width: 1.5),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, bool isReadOnly = false, bool obscureText = false, VoidCallback? onEyeTap, String? hint}) {
    return Container(
      decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        obscureText: obscureText,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.grey.shade500),
          suffixIcon: onEyeTap != null ? IconButton(icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: isDark ? Colors.white54 : Colors.grey), onPressed: onEyeTap) : null,
          border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildGradientButton({required String text, required VoidCallback onTap, required List<Color> colors}) {
    return Container(
      width: double.infinity, height: 56,
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: colors.first.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return TextButton.icon(
      onPressed: _deleteAccount,
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      label: const Text("Hesabımı Kalıcı Olarak Sil", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), backgroundColor: Colors.red.withOpacity(0.08), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }
}