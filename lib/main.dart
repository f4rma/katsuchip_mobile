import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <-- tambah ini
import 'package:katsuchip_app/pages/menu.dart';
import 'package:katsuchip_app/pages/cart.dart';
import 'package:katsuchip_app/models/models.dart';
import 'service/auth_service.dart';
import 'service/cart_repository.dart';
import 'package:katsuchip_app/pages/splash_screen.dart';
import 'package:katsuchip_app/pages/login.dart';
import 'package:katsuchip_app/pages/register.dart';
import 'package:katsuchip_app/pages/orders.dart';
import 'package:katsuchip_app/pages/profile_setup.dart';
import 'pages/profile.dart';
import 'pages/admin/admin_main.dart';
import 'pages/kurir/kurir_dashboard.dart';
import 'pages/midtrans_payment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFFF7ED)),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const Splashscreen(),
        '/auth': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (_) => const ProfilePage(),
        '/setup':  (_) => const ProfileSetupPage(),
        '/main': (context) => const MyApp(),
        '/admin': (context) => const AdminMainPage(),
        '/kurir': (context) => const KurirDashboard(),
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;
  final _repo = CartRepository();
  StreamSubscription<List<CartItem>>? _cartSub;

  // daftar menu kini diambil dari Firestore pada MenuPage

  List<CartItem> _cart = [];

  @override
  void initState() {
    super.initState();
    final uid = AuthService().currentUser?.uid;
    if (uid != null) {
      _cartSub = _repo.cartStream(uid).listen((items) {
        if (!mounted) return;
        setState(() => _cart = items);
      });
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  void _addToCart(MenuItemData item) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _repo.increment(uid, item, 1);
  }

  void _inc(CartItem e) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _repo.increment(uid, e.item, 1);
  }

  void _dec(CartItem e) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _repo.increment(uid, e.item, -1);
  }

  void _remove(CartItem e) {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    _repo.setItemQty(uid, e.item, 0);
  }

  

  @override
  Widget build(BuildContext context) {

    final pages = [
      MenuPage(onAdd: _addToCart),
      CartPage(
        items: _cart,
        onIncrease: _inc,
        onDecrease: _dec,
        onRemove: _remove,
        onCheckout: (total, address, payment) async {
          final uid = AuthService().currentUser?.uid;
          if (uid == null) return;
          
          // Place order dan dapatkan order ID & code
          final orderInfo = await _repo.placeOrder(
            uid,
            _cart,
            total,
            shippingAddress: address,
            paymentMethod: payment,
          );
          
          if (mounted) {
            // Launch Midtrans payment
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MidtransPaymentPage(
                  orderId: orderInfo['orderId']!,
                  orderCode: orderInfo['orderCode']!,
                  total: total,
                  items: _cart,
                  shippingAddress: address,
                ),
              ),
            );
          }
        },
        // Tambahan: callback ganti tab ke Menu
        onGoToMenu: () => setState(() => _selectedIndex = 0),
      ),
      OrdersPage(uid: AuthService().currentUser!.uid),
      const ProfilePage(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Handle back behavior manually
        if (_selectedIndex != 0) {
          if (mounted) setState(() => _selectedIndex = 0);
          return;
        }

        final brand = const Color(0xFFFF7A00);
        final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                ),
                const SizedBox(width: 8),
              ],
            ),
            content: const Text('Apakah Anda yakin ingin keluar dari KatsuChip?'),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brand,
                  side: BorderSide(color: brand),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Tidak'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Ya, Keluar'),
              ),
            ],
          ),
        );
        if (ok == true) {
          SystemNavigator.pop();
        }
  },
      child: Scaffold(
        body: pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFFF7A00),
          unselectedItemColor: Colors.black54,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu_rounded),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart_outlined),
                  Positioned(right: -6, top: -2, child: _CartBadge()),
                ],
              ),
              label: 'Keranjang',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Riwayat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Akun',
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Find the nearest _MyAppState to get cart length
    final state = context.findAncestorStateOfType<_MyAppState>();
    final count = state?._cart.fold<int>(0, (p, e) => p + e.qty) ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFFF7A00),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

 
