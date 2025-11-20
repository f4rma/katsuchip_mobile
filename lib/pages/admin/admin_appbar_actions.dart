import 'package:flutter/material.dart';
import '../../service/auth_service.dart';

List<Widget> adminAppBarActions(BuildContext context) {
  const brand = Color(0xFFFF7A00);
  Future<void> doLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Admin'),
        content: const Text('Yakin ingin logout dari akun admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await AuthService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  return [
    IconButton(
      tooltip: 'Logout',
      onPressed: doLogout,
      icon: const Icon(Icons.logout),
    )
  ];
}
