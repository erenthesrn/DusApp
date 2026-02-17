import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ROL SABİTLERİ
// ─────────────────────────────────────────────────────────────────────────────
const _kRoles = ['free', 'premium', 'admin'];

const _kRoleLabels = {
  'free': 'Ücretsiz',
  'premium': 'Premium',
  'admin': 'Admin',
};

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
  String? _roleFilter; // null = hepsi

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Stream ────────────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> _usersStream() {
    return _firestore
        .collection('users')
        .orderBy('email')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id; // uid'yi veriye göm
              return data;
            }).toList());
  }

  // ── Filtreleme ────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> users) {
    return users.where((u) {
      final q = _searchQuery.toLowerCase();
      final name = (u['name'] ?? u['displayName'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final matchSearch = q.isEmpty || name.contains(q) || email.contains(q);
      final role = u['role'] ?? 'free';
      final matchRole = _roleFilter == null || role == _roleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  // ── Rol Güncelle ──────────────────────────────────────────────────────────
  Future<void> _updateRole(String uid, String newRole) async {
    await _firestore.collection('users').doc(uid).update({'role': newRole});
  }

  // ── Düzenle Dialogu ───────────────────────────────────────────────────────
  void _showEditRoleDialog(BuildContext context, Map<String, dynamic> userData) {
    final String uid = userData['uid'] ?? '';
    final String name = userData['name'] ?? userData['displayName'] ?? 'İsimsiz';
    final String email = userData['email'] ?? '';
    String selectedRole = userData['role'] ?? 'free';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            title: Row(
              children: [
                // Avatar
                CircleAvatar(
                  backgroundColor: (_kRoleColors[selectedRole] ?? Colors.grey)
                      .withOpacity(0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _kRoleColors[selectedRole] ?? Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 24),
                const Text(
                  'Kullanıcı Rolü',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),

                // Rol seçici kartlar
                Row(
                  children: _kRoles.map((role) {
                    final isSelected = selectedRole == role;
                    final color = _kRoleColors[role]!;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => selectedRole = role),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color.withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    isSelected ? color : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _kRoleIcons[role],
                                  color: isSelected ? color : Colors.grey,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _kRoleLabels[role]!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected ? color : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // Değişiklik yoksa uyarı
                if (selectedRole == (userData['role'] ?? 'free')) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.info_outline,
                        size: 13, color: Colors.black38),
                    const SizedBox(width: 6),
                    Text(
                      'Mevcut rol seçili.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ]),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç',
                    style: TextStyle(color: Colors.black45)),
              ),
              ElevatedButton.icon(
                onPressed:
                    (isSaving || selectedRole == (userData['role'] ?? 'free'))
                        ? null
                        : () async {
                            setDialogState(() => isSaving = true);
                            try {
                              await _updateRole(uid, selectedRole);
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                _showToast(
                                  '✅ $name → ${_kRoleLabels[selectedRole]}',
                                  Colors.green,
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSaving = false);
                              if (ctx.mounted) {
                                _showToast(
                                    '❌ Güncelleme başarısız: $e', Colors.red);
                              }
                            }
                          },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
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

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Hata: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final allUsers = snapshot.data ?? [];
        final filtered = _applyFilters(allUsers);

        // Rol sayıları
        final counts = {
          for (var r in _kRoles)
            r: allUsers.where((u) => (u['role'] ?? 'free') == r).length,
        };

        return Column(
          children: [
            // ── İstatistik Şeridi ─────────────────────────────────────────
            _StatsBar(counts: counts, total: allUsers.length),

            // ── Arama + Filtre ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  // Arama kutusu
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'İsim veya e-posta ara...',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon:
                            const Icon(Icons.search, size: 20, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    size: 18, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.blue.shade100, width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1565C0), width: 1.5),
                        ),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Rol filtresi
                  PopupMenuButton<String?>(
                    onSelected: (val) => setState(() => _roleFilter = val),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: null,
                        child: Row(children: [
                          Icon(Icons.people_outline,
                              size: 18, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('Tümü'),
                        ]),
                      ),
                      ..._kRoles.map((r) => PopupMenuItem(
                            value: r,
                            child: Row(children: [
                              Icon(_kRoleIcons[r],
                                  color: _kRoleColors[r], size: 18),
                              const SizedBox(width: 8),
                              Text(_kRoleLabels[r]!),
                            ]),
                          )),
                    ],
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _roleFilter != null
                            ? (_kRoleColors[_roleFilter!] ?? Colors.grey)
                                .withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _roleFilter != null
                              ? (_kRoleColors[_roleFilter!] ?? Colors.grey)
                              : Colors.blue.shade100,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _roleFilter != null
                                ? _kRoleIcons[_roleFilter!]
                                : Icons.filter_list,
                            size: 20,
                            color: _roleFilter != null
                                ? _kRoleColors[_roleFilter!]
                                : Colors.grey,
                          ),
                          if (_roleFilter != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              _kRoleLabels[_roleFilter!]!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _kRoleColors[_roleFilter!],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sonuç sayısı
            if (_searchQuery.isNotEmpty || _roleFilter != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} sonuç',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ),
              ),

            // ── Kullanıcı Listesi ─────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search,
                              size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? '"$_searchQuery" için sonuç bulunamadı.'
                                : 'Kullanıcı bulunamadı.',
                            style: TextStyle(color: Colors.grey.shade400),
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
                        onEdit: () =>
                            _showEditRoleDialog(context, filtered[i]),
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

  const _StatsBar({required this.counts, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          // Toplam
          Expanded(
            child: _StatItem(
              label: 'Toplam',
              value: total,
              color: const Color(0xFF1565C0),
              icon: Icons.people_alt_outlined,
            ),
          ),
          _Divider(),
          // Free
          Expanded(
            child: _StatItem(
              label: _kRoleLabels['free']!,
              value: counts['free'] ?? 0,
              color: _kRoleColors['free']!,
              icon: _kRoleIcons['free']!,
            ),
          ),
          _Divider(),
          // Premium
          Expanded(
            child: _StatItem(
              label: _kRoleLabels['premium']!,
              value: counts['premium'] ?? 0,
              color: _kRoleColors['premium']!,
              icon: _kRoleIcons['premium']!,
            ),
          ),
          _Divider(),
          // Admin
          Expanded(
            child: _StatItem(
              label: _kRoleLabels['admin']!,
              value: counts['admin'] ?? 0,
              color: _kRoleColors['admin']!,
              icon: _kRoleIcons['admin']!,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 5),
        Text(
          '$value',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.black45)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Colors.grey.shade200,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KULLANICI KARTI
// ─────────────────────────────────────────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onEdit;

  const _UserTile({required this.userData, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final String name =
        userData['name'] ?? userData['displayName'] ?? 'İsimsiz';
    final String email = userData['email'] ?? '';
    final String role = userData['role'] ?? 'free';

    final Color roleColor = _kRoleColors[role] ?? Colors.grey;
    final String roleLabel = _kRoleLabels[role] ?? role;
    final IconData roleIcon = _kRoleIcons[role] ?? Icons.person;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.12),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: roleColor, fontSize: 16),
          ),
        ),
        title: Text(
          name,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              email,
              style:
                  const TextStyle(fontSize: 12, color: Colors.black45),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            // Rol rozeti
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: roleColor.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(roleIcon, size: 10, color: roleColor),
                  const SizedBox(width: 4),
                  Text(
                    roleLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: roleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              color: Color(0xFF1565C0), size: 20),
          tooltip: 'Rolü Düzenle',
          onPressed: onEdit,
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
