import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagementTab extends StatelessWidget {
  const UserManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Email'e göre sıralı getir
      stream: FirebaseFirestore.instance.collection('users').orderBy('email').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hata: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

        final users = snapshot.data!.docs;

        if (users.isEmpty) return const Center(child: Text("Kayıtlı kullanıcı yok."));

        return ListView.builder(
          itemCount: users.length,
          padding: const EdgeInsets.all(10),
          itemBuilder: (context, index) {
            var user = users[index];
            var userData = user.data() as Map<String, dynamic>;
            
            String name = userData['name'] ?? 'İsimsiz';
            String email = userData['email'] ?? 'No Email';
            String role = userData['role'] ?? 'free';

            Color roleColor = role == 'admin' ? Colors.red : (role == 'premium' ? Colors.purple : Colors.grey);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.2),
                  child: Icon(Icons.person, color: roleColor),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Chip(
                      label: Text(role.toUpperCase()),
                      backgroundColor: roleColor.withOpacity(0.1),
                      labelStyle: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditRoleDialog(context, user.id, name, role),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditRoleDialog(BuildContext context, String userId, String currentName, String currentRole) {
    String selectedRole = currentRole;
    final List<String> roles = ['free', 'premium', 'admin'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$currentName Rolünü Düzenle"),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: roles.map((role) {
                return RadioListTile<String>(
                  title: Text(role.toUpperCase()),
                  value: role,
                  groupValue: selectedRole,
                  activeColor: const Color(0xFF1565C0),
                  onChanged: (val) => setState(() => selectedRole = val!),
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(userId).update({'role': selectedRole});
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rol güncellendi!")));
              }
            },
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}