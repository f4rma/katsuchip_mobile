import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_appbar_actions.dart';
import 'admin_order_detail.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});
  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        title: const Text('Kelola Pesanan'),
        actions: adminAppBarActions(context),
      ),
      body: Column(children: [
        _StatusTabs(selected: _filter, onChanged: (v) => setState(() => _filter = v)),
        const SizedBox(height: 8),
        Expanded(child: _OrdersList(filter: _filter)),
      ]),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StatusTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      ['all', 'Semua'],
      ['pending', 'Menunggu'],
      ['processing', 'Diproses'],
      ['delivering', 'Diantar'],
      ['delivered', 'Selesai'],
      ['cancelled', 'Batal'],
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        for (final it in items) ...[
          _chip(
            label: it[1],
            selected: selected == it[0],
            onTap: () => onChanged(it[0]),
          ),
          const SizedBox(width: 8),
        ],
      ]),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    final orange = const Color(0xFFFF7A00);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? orange : Colors.white,
          border: Border.all(color: selected ? orange : Colors.orange.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _OrdersList extends StatelessWidget {
  final String filter;
  const _OrdersList({required this.filter});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collectionGroup('orders').orderBy('createdAt', descending: true);
    if (filter != 'all') {
      q = q.where('status', isEqualTo: filter);
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          final msg = (snap.error is FirebaseException)
              ? (snap.error as FirebaseException).message ?? 'Gagal memuat pesanan'
              : 'Gagal memuat pesanan';
          return _ErrorState(message: msg);
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final d = docs[i];
            return _OrderTile(doc: d);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: docs.length,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Periksa aturan keamanan Firestore untuk akun admin agar dapat membaca semua orders.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _OrderTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    final data = doc.data();
    final code = data['code'] as String? ?? doc.id;
    final uid = data['userId'] as String? ?? '-';
    final total = (data['total'] ?? 0) as num;
    final status = data['status'] as String? ?? 'pending';
    final kurirId = data['kurirId'] as String?;
    final kurirName = data['kurirName'] as String?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final when = createdAt != null ? '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}' : '-';

    void openDetail() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminOrderDetailPage(doc: doc)),
      );
    }

    Widget btn(String text, VoidCallback onTap, {Color? color}) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(backgroundColor: (color ?? orange), foregroundColor: Colors.white),
        child: Text(text),
      );
    }

    List<Widget> actions() {
      switch (status) {
        case 'pending':
          return [
            btn('Konfirmasi', () => _updateStatus(doc, 'confirmed', context)),
            btn('Batalkan', () => _updateStatus(doc, 'cancelled', context), color: Colors.grey),
          ];
        case 'confirmed':
          return [btn('Proses', () => _updateStatus(doc, 'processing', context))];
        case 'processing':
          return [btn('Antarkan', () => _updateToDelivering(doc, context))];
        case 'delivering':
          // Setelah antarkan, tidak ada tombol lagi - menunggu kurir
          if (kurirId != null && kurirName != null) {
            return [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delivery_dining, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Diantar oleh: $kurirName',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ];
          }
          return [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Menunggu kurir mengambil...',
                style: TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
              ),
            ),
          ];
        case 'delivered':
          return [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'Pesanan Selesai',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ];
        default:
          return [Container()];
      }
    }

    return GestureDetector(
      onTap: openDetail,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('#$code · UID: $uid', style: const TextStyle(fontWeight: FontWeight.w700))),
          _StatusPill(status: status),
        ]),
        const SizedBox(height: 6),
        Text('Total: ${_rupiah(total)} · $when', style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: actions()),
        ]),
      ),
    );
  }

  Future<void> _updateStatus(QueryDocumentSnapshot<Map<String, dynamic>> doc, String next, BuildContext context) async {
    await doc.reference.update({'status': next, 'updatedAt': FieldValue.serverTimestamp()});
    final uid = (doc.data()['userId'] as String?) ?? '';
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').add({
        'type': 'order_status',
        'orderId': doc.id,
        'status': next,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status diubah ke $next')));
    }
  }

  Future<void> _updateToDelivering(QueryDocumentSnapshot<Map<String, dynamic>> doc, BuildContext ctx) async {
    // Update status ke 'delivering' DAN set deliveryStatus ke 'waiting_pickup'
    // Ini akan membuat pesanan muncul di dashboard kurir aktif
    await doc.reference.update({
      'status': 'delivering',
      'deliveryStatus': 'waiting_pickup',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    final uid = (doc.data()['userId'] as String?) ?? '';
    if (uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('notifications').add({
        'type': 'order_status',
        'orderId': doc.id,
        'status': 'delivering',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Pesanan siap untuk diantar! Kurir dapat melihat pesanan ini.')),
      );
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'pending': 
        c = Colors.grey; 
        label = 'Menunggu';
        break;
      case 'processing': 
        c = Colors.orange; 
        label = 'Diproses';
        break;
      case 'delivering': 
        c = Colors.blue; 
        label = 'Diantar';
        break;
      case 'delivered': 
        c = Colors.green; 
        label = 'Selesai';
        break;
      case 'cancelled': 
        c = Colors.red; 
        label = 'Batal';
        break;
      default: 
        c = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
      child: Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
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
