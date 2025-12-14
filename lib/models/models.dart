class MenuItemData {
  final String id;
  final String name;
  final int price; // in rupiah
  final String imageAsset;
  final String description;
  final List<String> benefits;
  final int stock;
  final bool isActive;

  const MenuItemData({
    required this.id,
    required this.name,
    required this.price,
    required this.imageAsset,
    required this.description,
    required this.benefits,
    this.stock = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'imageAsset': imageAsset,
        'description': description,
        'benefits': benefits,
        'stock': stock,
        'isActive': isActive,
      };

  factory MenuItemData.fromMap(Map<String, dynamic> m) => MenuItemData(
        id: m['id'] as String,
        name: m['name'] as String,
        price: (m['price'] as num).toInt(),
        imageAsset: m['imageAsset'] as String,
        description: m['description'] as String,
        benefits: (m['benefits'] as List).cast<String>(),
        stock: ((m['stock'] ?? 0) as num).toInt(),
        isActive: (m['isActive'] as bool?) ?? true,
      );
}

class CartItem {
  final MenuItemData item;
  int qty;
  CartItem({required this.item, this.qty = 1});
  int get subtotal => item.price * qty;
}
