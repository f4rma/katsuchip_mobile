import 'package:flutter/material.dart';
import 'admin_dashboard.dart';
import 'admin_reports.dart';

class AdminMainPage extends StatefulWidget {
  const AdminMainPage({super.key});

  @override
  State<AdminMainPage> createState() => _AdminMainPageState();
}

class _AdminMainPageState extends State<AdminMainPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      AdminDashboardPage(),
      AdminReportsPage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFFF7A00),
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
        ],
      ),
    );
  }
}
