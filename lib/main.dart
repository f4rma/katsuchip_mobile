import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart'; // <-- tambah ini
import 'package:katsuchip_app/pages/menu.dart';
import 'package:katsuchip_app/pages/cart.dart';
import 'package:katsuchip_app/models/models.dart';
import 'service/auth_service.dart';
import 'service/cart_repository.dart';
import 'service/deep_link_handler.dart';
import 'package:katsuchip_app/pages/splash_screen.dart';
import 'package:katsuchip_app/pages/login.dart';
import 'package:katsuchip_app/pages/register.dart';
import 'package:katsuchip_app/pages/register_kurir.dart';
import 'package:katsuchip_app/pages/orders.dart';
import 'package:katsuchip_app/pages/profile_setup.dart';
import 'package:katsuchip_app/pages/ganti_pass_kurir.dart';
import 'pages/profile.dart';
import 'pages/admin/admin_main.dart';
import 'pages/kurir/kurir_dashboard.dart';
// import 'pages/midtrans_payment.dart'; // Dinonaktifkan sementara

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link when app is opened from terminated state
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print('Error getting initial URI: $e');
    }

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print('Error listening to URI: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    print('Received deep link: $uri');
    
    // Handle katsuchip://register-kurir?token=xxx
    if (uri.scheme == 'katsuchip' && uri.host == 'register-kurir') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        // Navigate to register kurir page with token
        _navigatorKey.currentState?.pushNamed(
          '/register-kurir',
          arguments: {'token': token},
        );
      }
    }
    
    // Handle katsuchip://payment/confirm/{orderId}
    // This is now handled by DeepLinkHandler in MainApp
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFFFFF7ED)),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle /register-kurir dengan token dari arguments
        if (settings.name == '/register-kurir') {
          String? token;
          
          // Cek dari arguments (dari deep link handler)
          if (settings.arguments != null) {
            if (settings.arguments is String) {
              token = settings.arguments as String;
            } else if (settings.arguments is Map) {
              token = (settings.arguments as Map)['token'] as String?;
            }
          }
          
          return MaterialPageRoute(
            builder: (context) => const RegisterKurirPage(),
          );
        }
        
        return null; // Let routes handle other paths
      },
      routes: {
        '/': (context) => const Splashscreen(),
        '/auth': (context) => const LoginPage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/profile': (_) => const ProfilePage(),
        '/setup':  (_) => const ProfileSetupPage(),
        '/first-login-change-password': (_) => const FirstLoginChangePasswordPage(),
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
    
    // Initialize deep link handler
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkHandler().initDeepLinks(context);
    });
    
    // Tambah logging untuk debug
    final user = AuthService().currentUser;
    print('?? User auth state:');
    print('   UID: ${user?.uid}');
    print('   Email: ${user?.email}');
    print('   Is authenticated: ${user != null}');
    
    final uid = user?.uid;
    if (uid != null) {
      print('?? Starting cart stream for UID: $uid');
      
      // Tambah delay kecil untuk memastikan auth sudah ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        
        _cartSub = _repo.cartStream(uid).listen(
          (items) {
            print('? Cart stream data received: ${items.length} items');
            for (final item in items) {
              print('   - ${item.item.name} x${item.qty}');
            }
            if (!mounted) return;
            setState(() => _cart = items);
          },
          onError: (error) {
            print('? Cart stream error: $error');
            print('   Error type: ${error.runtimeType}');
          },
        );
      });
    } else {
      print('?? No user authenticated, cart stream not started');
    }
  }

  @override
  void dispose() {
    _cartSub?.cancel();
    super.dispose();
  }

  void _addToCart(MenuItemData item) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan login terlebih dahulu')),
        );
      }
      return;
    }
    
    print('?? Adding to cart:');
    print('   User ID: $uid');
    print('   Item: ${item.name} (${item.id})');
    
    try {
      await _repo.increment(uid, item, 1);
      print('? Cart updated successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} ditambahkan ke keranjang'),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFFFF7A00),
          ),
        );
      }
    } catch (e) {
      print('? Error adding to cart: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan ke keranjang: ${e.toString().contains('permission') ? 'Akses ditolak' : 'Error'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _inc(CartItem e) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    try {
      await _repo.increment(uid, e.item, 1);
    } catch (err) {
      print('Error incrementing cart: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menambah jumlah: $err')),
        );
      }
    }
  }

  void _dec(CartItem e) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    try {
      await _repo.increment(uid, e.item, -1);
    } catch (err) {
      print('Error decrementing cart: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengurangi jumlah: $err')),
        );
      }
    }
  }

  void _goToMenu() {
    if (mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _goToOrders() {
    if (mounted) {
      setState(() => _selectedIndex = 2);
    }
  }

  void _remove(CartItem e) async {
    final uid = AuthService().currentUser?.uid;
    if (uid == null) return;
    try {
      await _repo.setItemQty(uid, e.item, 0);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${e.item.name} dihapus dari keranjang'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (err) {
      print('Error removing from cart: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus item: $err')),
        );
      }
    }
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
        onCheckout: (total, address, payment, {shippingFee, deliveryDistance, coordinates}) async {
          final uid = AuthService().currentUser?.uid;
          if (uid == null) return {};
          
          // Place order dan dapatkan order ID & code
          return await _repo.placeOrder(
            uid,
            _cart,
            total,
            shippingAddress: address,
            paymentMethod: payment,
            shippingFee: shippingFee,
            deliveryDistance: deliveryDistance,
            coordinates: coordinates,
          );
          
          // Dialog dan navigasi sekarang ditangani di CheckoutPage
        },
        // Tambahan: callback ganti tab ke Menu
        onGoToMenu: _goToMenu,
        // Tambahan: callback ganti tab ke Riwayat setelah checkout
        onGoToOrders: _goToOrders,
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

 
