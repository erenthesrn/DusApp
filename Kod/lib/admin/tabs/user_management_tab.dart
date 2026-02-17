import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROL SABİTLERİ
// ─────────────────────────────────────────────────────────────────────────────
const _kRoles = ['free', 'premium', 'admin'];
const _kRoleLabels = {'free': 'Ücretsiz', 'premium': 'Premium', 'admin': 'Admin'};
const _kRoleColors = {
  'free': Color(0xFF757575),
  'premium': Color(0xFF6A1B9A),
  'admin': Color(0xFF1565C0),
};
const _kRoleIcons = {
  'free': Icons.person_outline,
  'premium': Icons.star_outline,
  'admin': Icons.shield_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// USER MANAGEMENT TAB
// ─────────────────────────────────────────────────────────────────────────────
class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    ThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeProvider.instance.removeListener(_onThemeChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  Stream<List<Map<String, dynamic>>> _usersStream() {
    return _firestore.collection('users').orderBy('email').snapshots().map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return data;
          }).toList(),
        );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> users) {
    return users.where((u) {
      final q = _searchQuery.toLowerCase();
      final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || email.contains(q);
      final matchRole = _roleFilter == null || (u['role'] ?? 'free') == _roleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  Future<void> _updateRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({'role': newRole});
  }

  void _showEditRoleDialog(BuildContext context, Map<String, dynamic> userData) {
    final String uid = userData['uid'] ?? '';
    final String name = userData['name'] ?? userData['displayName'] ?? 'İsimsiz';
    final String email = userData['email'] ?? '';
    String selectedRole = userData['role'] ?? 'free';
    bool isSaving = false;
    final bool isDark = ThemeProvider.instance.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) {
          final Color dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
          final Color textColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;
          final Color subTextColor = isDark ? Colors.white38 : Colors.black45;
          final Color accentBlue = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);

          return AlertDialog(
            backgroundColor: dialogBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            title: Row(children: [
              CircleAvatar(
                backgroundColor: (_kRoleColors[selectedRole] ?? Colors.grey).withOpacity(0.18),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _kRoleColors[selectedRole] ?? Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                  Text(email, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: subTextColor)),
                ]),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(height: 24, color: isDark ? Colors.white12 : null),
                Text('Kullanıcı Rolü',
                    style: TextStyle(fontWeight: FontWeight.bold, color: accentBlue, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  children: _kRoles.map((role) {
                    final isSelected = selectedRole == role;
                    final color = _kRoleColors[role]!;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => setDS(() => selectedRole = role),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(isDark ? 0.2 : 0.1)
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected ? color : Colors.transparent, width: 2),
                            ),
                            child: Column(children: [
                              Icon(_kRoleIcons[role],
                                  color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey),
                                  size: 22),
                              const SizedBox(height: 4),
                              Text(_kRoleLabels[role]!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? color : (isDark ? Colors.white38 : Colors.grey),
                                  )),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedRole == (userData['role'] ?? 'free')) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.info_outline, size: 13, color: isDark ? Colors.white24 : Colors.black38),
                    const SizedBox(width: 6),
                    Text('Mevcut rol seçili.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white30 : Colors.grey.shade400)),
                  ]),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Vazgeç', style: TextStyle(color: isDark ? Colors.white38 : Colors.black45)),
              ),
              ElevatedButton.icon(
                onPressed: (isSaving || selectedRole == (userData['role'] ?? 'free'))
                    ? null
                    : () async {
                        setDS(() => isSaving = true);
                        try {
                          await _updateRole(uid, selectedRole);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _showToast('✅ $name → ${_kRoleLabels[selectedRole]}', Colors.green);
                          }
                        } catch (e) {
                          setDS(() => isSaving = false);
                          if (ctx.mounted) _showToast('❌ Güncelleme başarısız: $e', Colors.red);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showToast(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDark = ThemeProvider.instance.isDarkMode;
    final Color accentBlue = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);
    final Color inputFill = isDark ? const Color(0xFF0D1117) : Colors.white;
    final Color borderColor = isDark ? Colors.white12 : Colors.blue.shade100;
    final Color textColor = isDark ? const Color(0xFFE6EDF3) : Colors.black87;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}',
              style: const TextStyle(color: Colors.red)));
        }

        final allUsers = snapshot.data ?? [];
        final filtered = _applyFilters(allUsers);
        final counts = {
          for (var r in _kRoles) r: allUsers.where((u) => (u['role'] ?? 'free') == r).length,
        };

        return Column(
          children: [
            // ── İstatistik Şeridi ───────────────────────────────────────────
            _StatsBar(counts: counts, total: allUsers.length, isDark: isDark),

            // ── Arama + Filtre ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'İsim veya e-posta ara...',
                        hintStyle: TextStyle(
                            color: isDark ? Colors.white30 : Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search, size: 20,
                            color: isDark ? Colors.white38 : Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18,
                                    color: isDark ? Colors.white38 : Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: inputFill,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor, width: 1.2)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentBlue, width: 1.5)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rol filtresi
                  PopupMenuButton<String?>(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) => setState(() => _roleFilter = val),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: null,
                        child: Row(children: [
                          Icon(Icons.people_outline, size: 18,
                              color: isDark ? Colors.white54 : Colors.grey),
                          const SizedBox(width: 8),
                          Text('Tümü', style: TextStyle(color: textColor)),
                        ]),
                      ),
                      ..._kRoles.map((r) => PopupMenuItem(
                            value: r,
                            child: Row(children: [
                              Icon(_kRoleIcons[r], color: _kRoleColors[r], size: 18),
                              const SizedBox(width: 8),
                              Text(_kRoleLabels[r]!, style: TextStyle(color: textColor)),
                            ]),
                          )),
                    ],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _roleFilter != null
                            ? (_kRoleColors[_roleFilter!] ?? Colors.grey).withOpacity(isDark ? 0.2 : 0.1)
                            : inputFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _roleFilter != null
                                ? (_kRoleColors[_roleFilter!] ?? Colors.grey)
                                : borderColor,
                            width: 1.2),
                      ),
                      child: Row(children: [
                        Icon(
                          _roleFilter != null ? _kRoleIcons[_roleFilter!] : Icons.filter_list,
                          size: 20,
                          color: _roleFilter != null
                              ? _kRoleColors[_roleFilter!]
                              : (isDark ? Colors.white38 : Colors.grey),
                        ),
                        if (_roleFilter != null) ...[
                          const SizedBox(width: 4),
                          Text(_kRoleLabels[_roleFilter!]!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: _kRoleColors[_roleFilter!],
                                  fontWeight: FontWeight.bold)),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // Sonuç sayısı
            if (_searchQuery.isNotEmpty || _roleFilter != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${filtered.length} sonuç',
                      style: TextStyle(fontSize: 12,
                          color: isDark ? Colors.white30 : Colors.grey.shade500)),
                ),
              ),

            // ── Kullanıcı Listesi ───────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search, size: 52,
                              color: isDark ? Colors.white12 : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? '"$_searchQuery" için sonuç bulunamadı.'
                                : 'Kullanıcı bulunamadı.',
                            style: TextStyle(
                                color: isDark ? Colors.white30 : Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserTile(
                        userData: filtered[i],
                        isDark: isDark,
                        onEdit: () => _showEditRoleDialog(context, filtered[i]),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// İSTATİSTİK ŞERİDİ
// ─────────────────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final Map<String, int> counts;
  final int total;
  final bool isDark;

  const _StatsBar({required this.counts, required this.total, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.07)) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        Expanded(child: _StatItem(
            label: 'Toplam',
            value: total,
            color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
            icon: Icons.people_alt_outlined)),
        _BarDivider(isDark: isDark),
        Expanded(child: _StatItem(
            label: _kRoleLabels['free']!, value: counts['free'] ?? 0,
            color: _kRoleColors['free']!, icon: _kRoleIcons['free']!)),
        _BarDivider(isDark: isDark),
        Expanded(child: _StatItem(
            label: _kRoleLabels['premium']!, value: counts['premium'] ?? 0,
            color: _kRoleColors['premium']!, icon: _kRoleIcons['premium']!)),
        _BarDivider(isDark: isDark),
        Expanded(child: _StatItem(
            label: _kRoleLabels['admin']!, value: counts['admin'] ?? 0,
            color: _kRoleColors['admin']!, icon: _kRoleIcons['admin']!)),
      ]),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatItem({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(height: 5),
      Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]);
  }
}

class _BarDivider extends StatelessWidget {
  final bool isDark;
  const _BarDivider({required this.isDark});

  @override
  Widget build(BuildContext context) =>
      Container(height: 36, width: 1, color: isDark ? Colors.white12 : Colors.grey.shade200);
}

// ─────────────────────────────────────────────────────────────────────────────
// KULLANICI KARTI
// ─────────────────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final bool isDark;
  final VoidCallback onEdit;

  const _UserTile({required this.userData, required this.isDark, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? userData['displayName'] ?? 'İsimsiz';
    final String email = userData['email'] ?? '';
    final String role = userData['role'] ?? 'free';
    final Color roleColor = _kRoleColors[role] ?? Colors.grey;
    final String roleLabel = _kRoleLabels[role] ?? role;
    final IconData roleIcon = _kRoleIcons[role] ?? Icons.person;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.06)) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
              blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
          ),
        ),
        title: Text(name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                color: isDark ? const Color(0xFFE6EDF3) : Colors.black87)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(email,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black45)),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: roleColor.withOpacity(isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor.withOpacity(isDark ? 0.35 : 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(roleIcon, size: 10, color: roleColor),
              const SizedBox(width: 4),
              Text(roleLabel,
                  style: TextStyle(fontSize: 10, color: roleColor, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        trailing: IconButton(
          icon: Icon(Icons.edit_outlined,
              color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0), size: 20),
          tooltip: 'Rolü Düzenle',
          onPressed: onEdit,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
