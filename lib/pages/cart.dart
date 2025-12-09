import 'package:flutter/material.dart';
import '../models/models.dart';
import 'checkout.dart';
 

typedef OnCheckout = Future<Map<String, String>> Function(
  double total,
  Map<String, dynamic> address,
  String paymentMethod, {
  int? shippingFee,
  double? deliveryDistance,
  Map<String, double>? coordinates,
});

class CartPage extends StatefulWidget {
  final List<CartItem> items;
  final void Function(CartItem) onIncrease;
  final void Function(CartItem) onDecrease;
  final void Function(CartItem) onRemove;
  final OnCheckout onCheckout;

  // Tambahan: callback untuk pindah ke tab Menu
  final VoidCallback onGoToMenu;
  
  // Tambahan: callback untuk pindah ke tab Riwayat setelah checkout
  final VoidCallback? onGoToOrders;

  const CartPage({
    super.key,
    required this.items,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    required this.onCheckout,
    required this.onGoToMenu, // new
    this.onGoToOrders,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // Address/payment selection now handled in CheckoutPage

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A00);
    final total = widget.items.fold<int>(0, (p, e) => p + e.subtotal);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text('Keranjang Belanja',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const SizedBox(height: 16),

            if (widget.items.isEmpty)
              Column(
                children: [
                  const SizedBox(height: 80),
                  const Text('Keranjang Kosong',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('Yuk, Pilih menu favoritmu dulu!'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: widget.onGoToMenu, // bukan Navigator
                    child: const Text('Lihat Menu'),
                  )
                ],
              )
            else
              ...[
                ...widget.items.map((e) => _CartRow(
                      item: e,
                      onDec: () => widget.onDecrease(e),
                      onInc: () => widget.onIncrease(e),
                      onRemove: () => widget.onRemove(e),
                    )),
                const SizedBox(height: 12),
                _SummaryCard(total: total),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                        builder: (_) => CheckoutPage(
                          items: widget.items,
                          onCheckout: widget.onCheckout, // forward
                        ),
                      ));
                      
                      // Jika checkout berhasil, pindah ke tab Riwayat
                      if (result == true && widget.onGoToOrders != null) {
                        widget.onGoToOrders!();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Checkout'),
                  ),
                )
              ]
          ],
        ),
      ),
    );
  }

  // previously had a bottom-sheet checkout; now replaced by a full CheckoutPage
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onRemove;
  const _CartRow({
    required this.item,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _imageThumb(item.item.imageAsset),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_formatRupiah(item.item.price)),
              ],
            ),
          ),
          Row(
            children: [
              _SmallIconBtn(icon: Icons.remove, onTap: onDec),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text('${item.qty}'),
              ),
              _SmallIconBtn(icon: Icons.add, onTap: onInc),
            ],
          ),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete, color: Colors.redAccent))
        ],
      ),
    );
  }
}

class _SmallIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Icon(icon, size: 16, color: const Color(0xFFFF7A00)),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  const _SummaryCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Column(
        children: [
          const _RowSpaced('Subtotal', ''),
          const _RowSpaced('Ongkos Kirim', 'GRATIS'),
          const Divider(),
          _RowSpaced('Total', _formatRupiah(total), emphasize: true),
        ],
      ),
    );
  }
}

// Removed _CheckoutSection (was used by old bottom sheet)

class _RowSpaced extends StatelessWidget {
  final String left;
  final String right;
  final bool emphasize;
  const _RowSpaced(this.left, this.right, {this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: style),
          Text(right, style: style),
        ],
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

Widget _imageThumb(String pathOrUrl) {
  const double w = 56, h = 56;
  Widget placeholder() => Container(
        width: w,
        height: h,
        color: Colors.orange.shade50,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, color: Colors.orange, size: 18),
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
