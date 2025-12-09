import 'package:flutter/material.dart';
import 'detail.dart';
import '../models/models.dart';
import '../service/menu_repository.dart';

class MenuPage extends StatefulWidget {
  final void Function(MenuItemData) onAdd;

  const MenuPage({super.key, required this.onAdd});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late final MenuRepository _repo = MenuRepository();
  late final Stream<List<Map<String, dynamic>>> _menuStream = _repo.streamMenus();

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);

    // Fallback daftar produk statis (6 item) berbasis assets
    const staticItems = <MenuItemData>[
      MenuItemData(
        id: 'miechili',
        name: 'Mie Katsu Chilli Oil',
        price: 15000,
        imageAsset: 'assets/images/miechili.jpg',
        description: 'Mie katsu dengan chilli oil gurih pedas.',
        benefits: [],
      ),
      MenuItemData(
        id: 'bentochili',
        name: 'Bento Katsu Chilli Oil',
        price: 20000,
        imageAsset: 'assets/images/bentochili.jpg',
        description: 'Paket bento katsu dengan chilli oil.',
        benefits: [],
      ),
      MenuItemData(
        id: 'bentosaus',
        name: 'Bento Katsu Spesial Saus',
        price: 20000,
        imageAsset: 'assets/images/bentosaus.jpg',
        description: 'Paket bento katsu dengan saus spesial.',
        benefits: [],
      ),
      MenuItemData(
        id: 'nasichili',
        name: 'Nasi Katsu Chilli Oil',
        price: 15000,
        imageAsset: 'assets/images/nasichili.jpg',
        description: 'Nasi katsu disiram chilli oil.',
        benefits: [],
      ),
      MenuItemData(
        id: 'miespesial',
        name: 'Mi Goreng Spesial Katsu',
        price: 18000,
        imageAsset: 'assets/images/miespesial.jpg',
        description: 'Mi goreng dengan topping katsu spesial.',
        benefits: [],
      ),
      MenuItemData(
        id: 'nasisaus',
        name: 'Nasi Katsu Spesial Saus',
        price: 15000,
        imageAsset: 'assets/images/nasisaus.jpg',
        description: 'Nasi katsu dengan saus spesial.',
        benefits: [],
      ),
    ];
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _menuStream,
          builder: (context, snap) {
            final menus = snap.data ?? const [];
            final items = menus.isNotEmpty
                ? menus.map(_fromMenuDoc).toList()
                : staticItems; // jika Firestore kosong, gunakan assets
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Halo!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                )),
                            SizedBox(height: 4),
                            Text('Mau pesan apa hari ini?',
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                      const CircleAvatar(radius: 22, backgroundColor: Colors.white24),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('Top Picks',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 12),

                if (snap.connectionState == ConnectionState.waiting)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  )),
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Gagal memuat menu',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (!snap.hasError && snap.connectionState == ConnectionState.active && menus.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: const [
                        Icon(Icons.restaurant_menu, size: 48, color: Colors.black26),
                        SizedBox(height: 8),
                        Text('Menampilkan menu dari katalog KatsuChip.'),
                      ],
                    ),
                  ),
                ...items.map((item) => _MenuCard(
                      item: item,
                      onAdd: () {
                        // Hanya panggil callback; SnackBar ditangani di parent (orange)
                        widget.onAdd(item);
                      },
                      onOpen: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailPage(item: item, onAdd: widget.onAdd),
                          ),
                        );
                      },
                    )),

                const SizedBox(height: 16),
                // Promo card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Promo Hari ini!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          )),
                      SizedBox(height: 4),
                      Text('Gratis ongkir untuk pembelian min. Rp 50.000',
                          style: TextStyle(color: Colors.white70)),
                      SizedBox(height: 2),                    
                    ],
                  ),
                )
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuItemData item;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  const _MenuCard({
    required this.item,
    required this.onAdd,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _image(item.imageAsset, 72, 72),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  const Text('Deskripsi Menu', style: TextStyle(color: Colors.black54, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(_formatRupiah(item.price),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Tambah'),
            )
          ],
        ),
      ),
    );
  }
}

String _formatRupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write('.');
  }
  return 'Rp ${buf.toString()}';
}

MenuItemData _fromMenuDoc(Map<String, dynamic> m) {
  final id = (m['id'] as String?) ?? '';
  final name = (m['name'] as String?) ?? '';
  final price = ((m['price'] ?? 0) as num).toInt();
  final image = (m['imageUrl'] as String?) ?? (m['imageAsset'] as String?) ?? '';
  final desc = (m['description'] as String?) ?? '';
  final benefits = (m['benefits'] as List?)?.cast<String>() ?? const <String>[];
  return MenuItemData(
    id: id,
    name: name,
    price: price,
    imageAsset: image,
    description: desc,
    benefits: benefits,
  );
}

Widget _image(String pathOrUrl, double w, double h) {
  Widget placeholder() => Container(
        width: w,
        height: h,
        color: Colors.orange.shade50,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 28),
      );

  if (pathOrUrl.startsWith('http')) {
    return Image.network(
      pathOrUrl,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder(),
    );
  }
  if (pathOrUrl.isEmpty) return placeholder();
  return Image.asset(
    pathOrUrl,
    width: w,
    height: h,
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => placeholder(),
  );
}
