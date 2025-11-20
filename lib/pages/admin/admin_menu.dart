import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../service/menu_repository.dart';
import '../../service/auth_service.dart';
import 'admin_appbar_actions.dart';

class AdminMenuPage extends StatelessWidget {
  const AdminMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = MenuRepository();
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Kelola Menu'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
        actions: adminAppBarActions(context),
      ),
      // Admin tidak menambah menu baru; hanya kelola ketersediaan & stok
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repo.streamMenus(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final menus = snap.data!;
          if (menus.isEmpty) {
            final uid = AuthService().currentUser?.uid;
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: uid == null
                  ? null
                  : FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (ctx, roleSnap) {
                final isAdmin = (roleSnap.data?.data()?['role'] == 'admin');
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Belum ada data menu.'),
                      if (isAdmin) ...[
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () async {
                            await MenuRepository().seedInitialMenusIfEmpty();
                          },
                          child: const Text('Sinkronkan Katalog (6 Item)'),
                        ),
                      ]
                    ],
                  ),
                );
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: menus.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = menus[i];
              return _MenuTile(menu: m);
            },
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final Map<String, dynamic> menu;
  const _MenuTile({required this.menu});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final id = menu['id'] as String;
    final name = menu['name'] as String? ?? '';
    final price = (menu['price'] ?? 0) as num;
    final stock = (menu['stock'] ?? 0) as num;
    final available = (menu['isAvailable'] ?? true) as bool;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(_rupiah(price)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (available ? Colors.green : Colors.grey).withValues(alpha: .15), borderRadius: BorderRadius.circular(10)),
            child: Text(available ? 'Tersedia' : 'Tidak Tersedia', style: TextStyle(color: available ? Colors.green : Colors.grey, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Text('Stok: $stock', style: const TextStyle(color: Colors.black54)),
          const Spacer(),
          IconButton(onPressed: () => _delete(context, id), icon: const Icon(Icons.delete_outline)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _smallBtn('Tambah Stok', () => MenuRepository().adjustStock(id, 1)),
          const SizedBox(width: 8),
          _smallBtn('Kurangi Stok', () => MenuRepository().adjustStock(id, -1)),
          const SizedBox(width: 8),
          _smallBtn(
            available ? 'Matikan' : 'Aktifkan',
            () => MenuRepository().updateMenu(id, {'isAvailable': !available}),
            color: available ? Colors.grey : orange,
          ),
        ]),
      ]),
    );
  }

  Widget _smallBtn(String text, VoidCallback onTap, {Color color = const Color(0xFFFF7A00)}) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
      child: Text(text),
    );
  }

  Future<void> _delete(BuildContext context, String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Hapus menu ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) await MenuRepository().deleteMenu(id);
  }
}

String _rupiah(num n) {
  final s = n.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    b.write(s[i]);
    if (idx > 1 && idx % 3 == 1) b.write('.');
  }
  return 'Rp $b';
}

