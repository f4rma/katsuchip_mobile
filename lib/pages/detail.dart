import 'package:flutter/material.dart';
import '../models/models.dart';

class DetailPage extends StatelessWidget {
  final MenuItemData item;
  final void Function(MenuItemData)? onAdd;

  const DetailPage({super.key, required this.item, this.onAdd});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Column(
          children: [
              // image header
              Stack(
                children: [
                  _image(item.imageAsset, double.infinity, 220),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.close),
                        ),
                      ),
                    ),
                  )
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(item.name,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_formatRupiah(item.price),
                        style: const TextStyle(
                            fontSize: 20, color: orange, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    const Text('Deskripsi',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(item.description),
                    const SizedBox(height: 16),
                    const Text('Yang Anda Dapat',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: item.benefits
                          .map((b) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: orange),
                                  const SizedBox(width: 8),
                                  Text(b),
                                ],
                              ))
                          .toList(),
                    )
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        onAdd?.call(item);
                        // Delay navigation sedikit agar user melihat feedback
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (context.mounted) Navigator.pop(context);
                        });
                      },
                      child: const Text('Tambah'),
                    ),
                  ),
                ),
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

Widget _image(String pathOrUrl, double w, double h) {
  Widget placeholder() => Container(
        width: w,
        height: h,
        color: Colors.orange.shade50,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 36),
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
