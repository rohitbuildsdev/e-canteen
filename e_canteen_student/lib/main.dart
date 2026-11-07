import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
    apiKey: 'AIzaSyDhXAmT9VkM2kkIFdtk99PWXXbuXtdjK50',
    authDomain: 'e-canteen-bd8cb.firebaseapp.com',
    projectId: 'e-canteen-bd8cb',
    storageBucket: 'e-canteen-bd8cb.firebasestorage.app',
    messagingSenderId: '795910644169',
    appId: '1:795910644169:web:1504a536ea15d83a228818',
  ));
  runApp(const ECanteenApp());
}

// ============================================================
// APP
// ============================================================

class ECanteenApp extends StatelessWidget {
  const ECanteenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Canteen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F5EF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE86A17),
          brightness: Brightness.light,
        ),
        fontFamily: 'Arial',
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        initialData: FirebaseAuth.instance.currentUser,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final user = snapshot.data;
          return user == null
              ? const AuthScreen()
              : ECanteenRoot(key: ValueKey(user.uid));
        },
      );
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool creatingAccount = false;
  bool busy = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> submit() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (!email.contains('@') || password.length < 6) {
      message('Enter a valid email and a password with at least 6 characters.');
      return;
    }
    setState(() => busy = true);
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser;
      if (creatingAccount && current != null && current.isAnonymous) {
        await current.linkWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else if (creatingAccount) {
        await auth.createUserWithEmailAndPassword(
            email: email, password: password);
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
      if (mounted && Navigator.of(context).canPop())
        Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      final text = switch (e.code) {
        'email-already-in-use' =>
          'That email already has an account. Choose Log in.',
        'invalid-email' => 'That email address is not valid.',
        'weak-password' =>
          'Choose a stronger password (at least 6 characters).',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email or password is incorrect.',
        _ => e.message ?? 'Authentication failed. Please try again.',
      };
      if (mounted) message(text);
    } catch (e) {
      if (mounted) message('Could not complete authentication: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE86A17),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.restaurant,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    creatingAccount ? 'Create your account' : 'Welcome back',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF241A14)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    creatingAccount
                        ? 'Save your account and keep your order history.'
                        : 'Log in to continue to E-Canteen.',
                    style:
                        const TextStyle(color: Color(0xFF766A62), fontSize: 15),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration:
                        _inputDecoration('Email address', Icons.email_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    autofillHints: [
                      creatingAccount
                          ? AutofillHints.newPassword
                          : AutofillHints.password
                    ],
                    decoration: _inputDecoration('Password', Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        icon: Icon(obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (!busy) submit();
                    },
                  ),
                  if (creatingAccount) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Use at least 6 characters to keep your account secure.',
                      style: TextStyle(color: Color(0xFF766A62), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: busy ? null : submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE86A17),
                          foregroundColor: Colors.white),
                      child: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(creatingAccount ? 'Create account' : 'Log in',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () =>
                            setState(() => creatingAccount = !creatingAccount),
                    child: Text(creatingAccount
                        ? 'Already have an account? Log in'
                        : 'New here? Create an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ROOT
// ============================================================

class ECanteenRoot extends StatefulWidget {
  const ECanteenRoot({super.key});

  @override
  State<ECanteenRoot> createState() => _ECanteenRootState();
}

class _ECanteenRootState extends State<ECanteenRoot> {
  bool loading = true;
  bool onboarded = false;

  String studentName = '';
  String studentId = '';
  String studentBranch = '';

  int currentTab = 0;

  final Map<String, int> cart = {};

  List<OrderModel> orders = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _menuSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<FoodItem> menu = [];

  @override
  void initState() {
    super.initState();
    loadApp();
    _menuSubscription =
        _firestore.collection('menu_items').snapshots().listen((snapshot) {
      final liveMenu = snapshot.docs
          .where((doc) => doc.data()['active'] != false)
          .map((doc) {
        final data = doc.data();
        final rawPrice = data['price'];
        return FoodItem(
          id: doc.id,
          name: (data['name'] ?? 'Food item').toString(),
          category: (data['category'] ?? 'Other').toString(),
          price: rawPrice is num
              ? rawPrice.toDouble()
              : double.tryParse('$rawPrice') ?? 0,
          emoji: (data['emoji'] ?? '🍽️').toString(),
          description: (data['description'] ?? '').toString(),
          popular: data['popular'] == true,
          available: data['available'] != false,
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        menu = liveMenu;
        cart.removeWhere((id, quantity) => !menu.any((item) => item.id == id));
      });
    }, onError: (Object error) {
      if (mounted) showSnack('Could not load live menu: $error');
    });
    _ordersSubscription = _firestore
        .collection('orders')
        .where('studentUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final remoteOrders = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawItems = data['items'];
        final items = <OrderLineItem>[];
        if (rawItems is List) {
          for (final raw in rawItems) {
            if (raw is Map) {
              final item = Map<String, dynamic>.from(raw);
              items.add(OrderLineItem(
                foodId: (item['foodId'] ?? '').toString(),
                name: (item['name'] ?? 'Food item').toString(),
                price: (item['price'] as num?)?.toDouble() ?? 0,
                quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                emoji: (item['emoji'] ?? '🍽️').toString(),
              ));
            }
          }
        }
        final created = data['createdAt'];
        final createdAt =
            created is Timestamp ? created.toDate() : DateTime.now();
        final method = (data['paymentMethod'] ?? 'Cash').toString();
        return OrderModel(
          id: doc.id,
          orderNumber: (data['orderNumber'] ?? '').toString(),
          items: items,
          total: (data['total'] as num?)?.toDouble() ?? 0,
          pickupTime: (data['pickupTime'] ?? '').toString(),
          paymentMethod: method.toLowerCase().contains('upi')
              ? PaymentMethod.upi
              : PaymentMethod.cash,
          status: _studentStatus((data['status'] ?? 'newOrder').toString()),
          createdAt: createdAt,
        );
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        // Firestore is authoritative; this also loads orders on another device.
        orders = remoteOrders;
      });
      saveOrders();
    }, onError: (Object error) {
      if (mounted) showSnack('Could not sync order updates: $error');
    });
  }

  @override
  void dispose() {
    _menuSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  OrderStatus _studentStatus(String value) => switch (value) {
        'ready' => OrderStatus.ready,
        'collected' => OrderStatus.completed,
        'cancelled' => OrderStatus.cancelled,
        'newOrder' => OrderStatus.preparing,
        'confirmed' || 'preparing' => OrderStatus.preparing,
        _ => OrderStatus.preparing,
      };

  String _prefKey(String key) =>
      '${FirebaseAuth.instance.currentUser?.uid ?? 'signed_out'}_$key';

  Future<void> loadApp() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString(_prefKey('student_name'));
    final savedId = prefs.getString(_prefKey('student_id'));
    final savedBranch = prefs.getString(_prefKey('student_branch'));

    final savedOrders = prefs.getString(_prefKey('orders'));

    if (savedOrders != null && savedOrders.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedOrders);

        if (decoded is List) {
          orders = decoded
              .map(
                (item) => OrderModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
      } catch (_) {
        orders = [];
      }
    }

    setState(() {
      studentName = savedName ?? '';
      studentId = savedId ?? '';
      studentBranch = savedBranch ?? '';
      onboarded = savedName != null &&
          savedId != null &&
          savedBranch != null &&
          savedName.isNotEmpty &&
          savedId.isNotEmpty &&
          savedBranch.isNotEmpty;
      loading = false;
    });
  }

  Future<void> saveStudent(
    String name,
    String id,
    String branch,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_prefKey('student_name'), name);
    await prefs.setString(_prefKey('student_id'), id);
    await prefs.setString(_prefKey('student_branch'), branch);

    setState(() {
      studentName = name;
      studentId = id;
      studentBranch = branch;
      onboarded = true;
    });
  }

  Future<void> saveOrders() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(
      orders.map((order) => order.toJson()).toList(),
    );

    await prefs.setString(_prefKey('orders'), encoded);
  }

  int get cartCount {
    return cart.values.fold(0, (sum, value) => sum + value);
  }

  double get cartTotal {
    double total = 0;

    for (final entry in cart.entries) {
      final item = menu.firstWhere(
        (food) => food.id == entry.key,
      );

      total += item.price * entry.value;
    }

    return total;
  }

  List<OrderModel> get activeOrders {
    return orders
        .where(
          (order) =>
              order.status == OrderStatus.preparing ||
              order.status == OrderStatus.ready,
        )
        .toList();
  }

  void addToCart(FoodItem item) {
    if (!item.available) {
      showSnack('${item.name} is currently unavailable.');
      return;
    }
    setState(() {
      cart[item.id] = (cart[item.id] ?? 0) + 1;
    });
  }

  void removeFromCart(FoodItem item) {
    setState(() {
      if (!cart.containsKey(item.id)) return;

      if (cart[item.id]! <= 1) {
        cart.remove(item.id);
      } else {
        cart[item.id] = cart[item.id]! - 1;
      }
    });
  }

  Future<bool> createOrder({
    required DateTime pickupAt,
    required PaymentMethod paymentMethod,
  }) async {
    if (!pickupAt.isAfter(DateTime.now().add(const Duration(minutes: 14)))) {
      showSnack('That pickup slot has passed. Please choose another time.');
      return false;
    }
    if (pickupAt.hour < 10 ||
        pickupAt.hour > 17 ||
        (pickupAt.hour == 17 && pickupAt.minute > 0)) {
      showSnack('Pickup is available between 10:00 AM and 5:00 PM.');
      return false;
    }
    final pickupTime = _formatPickupDateTime(pickupAt);
    if (cart.isEmpty) {
      showSnack('Your cart is empty.');
      return false;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showSnack('Could not sign in. Please reopen the app and try again.');
      return false;
    }

    final orderItems = <OrderLineItem>[];
    for (final entry in cart.entries) {
      final matches = menu.where((item) => item.id == entry.key);
      if (matches.isEmpty || !matches.first.available) {
        showSnack('An item in your cart is no longer available.');
        return false;
      }
      final food = matches.first;
      orderItems.add(OrderLineItem(
        foodId: food.id,
        name: food.name,
        price: food.price,
        quantity: entry.value,
        emoji: food.emoji,
      ));
    }

    final orderRef = _firestore.collection('orders').doc();
    final now = DateTime.now();
    // Use the canteen's local calendar date. Each date has its own counter.
    final dateKey = '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
    final counterRef =
        _firestore.collection('daily_order_counters').doc(dateKey);
    final total = orderItems.fold<double>(
        0, (sum, item) => sum + item.price * item.quantity);
    try {
      await _firestore.runTransaction((transaction) async {
        // Firestore retries this transaction if another student orders at once.
        final counterSnapshot = await transaction.get(counterRef);
        final previousNumber = counterSnapshot.exists
            ? ((counterSnapshot.data()?['lastNumber'] as num?)?.toInt() ?? 0)
            : 0;
        final nextNumber = previousNumber + 1;
        final orderNumber = 'EC-${nextNumber.toString().padLeft(3, '0')}';

        transaction.set(counterRef, {
          'dateKey': dateKey,
          'lastNumber': nextNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(orderRef, {
          'orderNumber': orderNumber,
          'orderDate': dateKey,
          'studentUid': user.uid,
          'studentName': studentName,
          'studentId': studentId,
          'studentBranch': studentBranch,
          'items': orderItems
              .map((item) => {
                    'foodId': item.foodId,
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity,
                    'emoji': item.emoji,
                  })
              .toList(),
          'total': total,
          'pickupTime': pickupTime,
          'pickupAt': Timestamp.fromDate(pickupAt),
          'paymentMethod':
              paymentMethod == PaymentMethod.upi ? 'UPI (pending)' : 'Cash',
          'status': 'newOrder',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'note': '',
          'estimatedPrepMinutes': 10,
        });
      });
    } catch (error, stackTrace) {
      debugPrint('PLACE ORDER FAILED: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: $error'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      return false;
    }

    if (!mounted) return true;
    setState(() {
      cart.clear();
      currentTab = 2;
    });
    return true;
  }

  Future<void> cancelOrder(OrderModel order) async {
    try {
      await _firestore.collection('orders').doc(order.id).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      if (mounted) showSnack('Could not cancel order: $error');
    }
  }

  void completeOrderDemo(OrderModel order) {
    setState(() {
      order.status = OrderStatus.ready;
    });

    saveOrders();
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!onboarded) {
      return OnboardingScreen(
        onComplete: saveStudent,
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: currentTab,
        children: [
          HomeScreen(
            studentName: studentName,
            activeOrders: activeOrders,
            popularItems: menu.where((item) => item.popular).toList(),
            onBrowseMenu: () {
              setState(() {
                currentTab = 1;
              });
            },
            onAdd: addToCart,
          ),
          MenuScreen(
            menu: menu,
            cart: cart,
            onAdd: addToCart,
            onRemove: removeFromCart,
          ),
          OrdersScreen(
            orders: orders,
            onCancel: cancelOrder,
            onDemoReady: completeOrderDemo,
          ),
          ProfileScreen(
            name: studentName,
            id: studentId,
            branch: studentBranch,
            orderCount: orders.length,
            onSignOut: () async {
              await FirebaseAuth.instance.signOut();
            },
            onManageAccount: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: currentTab,
        cartCount: cartCount,
        onTap: (index) {
          setState(() {
            currentTab = index;
          });
        },
      ),
      floatingActionButton: cartCount > 0 && currentTab != 2
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFE86A17),
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CartScreen(
                      menu: menu,
                      cart: cart,
                      onAdd: addToCart,
                      onRemove: removeFromCart,
                      total: cartTotal,
                      onCheckoutComplete: () {
                        setState(() {
                          currentTab = 2;
                        });
                      },
                      onPlaceOrder: createOrder,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text('Cart • ₹${cartTotal.toStringAsFixed(0)}'),
            )
          : null,
    );
  }
}

// ============================================================
// ONBOARDING
// ============================================================

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function(
    String name,
    String id,
    String branch,
  ) onComplete;

  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final nameController = TextEditingController();
  final idController = TextEditingController();

  String? branch;

  bool saving = false;

  final branches = const [
    'CSE',
    'CSE (AI&ML)',
    'ECE',
    'EEE',
    'ME',
    'Civil',
    'Other',
  ];

  Future<void> submit() async {
    final name = nameController.text.trim();
    final id = idController.text.trim();

    if (name.isEmpty || id.isEmpty || branch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all details.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    await widget.onComplete(
      name,
      id,
      branch!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE86A17),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.restaurant_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Welcome to\nE-Canteen',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                      color: Color(0xFF241A14),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Order your food before you reach the canteen.',
                    style: TextStyle(
                      fontSize: 17,
                      color: Color(0xFF766A62),
                    ),
                  ),
                  const SizedBox(height: 38),
                  _InputField(
                    controller: nameController,
                    label: 'Full Name',
                    hint: 'Enter your name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _InputField(
                    controller: idController,
                    label: 'Student ID',
                    hint: 'Example: 24A81A0501',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: branch,
                    decoration: _inputDecoration(
                      'Branch',
                      Icons.school_outlined,
                    ),
                    items: branches
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        branch = value;
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE86A17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: saving ? null : submit,
                      child: saving
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Enter E-Canteen',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Your details stay on this device.',
                      style: TextStyle(
                        color: Color(0xFF9A8F87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class HomeScreen extends StatelessWidget {
  final String studentName;
  final List<OrderModel> activeOrders;
  final List<FoodItem> popularItems;
  final VoidCallback onBrowseMenu;
  final Function(FoodItem) onAdd;

  const HomeScreen({
    super.key,
    required this.studentName,
    required this.activeOrders,
    required this.popularItems,
    required this.onBrowseMenu,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOOD DAY 👋',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE86A17),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF241A14),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: Color(0xFF241A14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF2B211C),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A3A30),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: Color(0xFF61D18B),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'CANTEEN OPEN',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Skip the queue.\nEnjoy your break.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Order ahead and collect when your food is ready.',
                    style: TextStyle(
                      color: Color(0xFFC9BCB3),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE86A17),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onBrowseMenu,
                    child: const Text('Browse Menu'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (activeOrders.isNotEmpty) ...[
              const Text(
                'YOUR ACTIVE ORDERS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: Color(0xFF766A62),
                ),
              ),
              const SizedBox(height: 12),
              ...activeOrders.take(2).map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ActiveOrderCard(order: order),
                    ),
                  ),
              const SizedBox(height: 18),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Popular today',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF241A14),
                  ),
                ),
                TextButton(
                  onPressed: onBrowseMenu,
                  child: const Text('See all'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 245,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popularItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final item = popularItems[index];

                  return FoodCard(
                    item: item,
                    quantity: 0,
                    onAdd: () => onAdd(item),
                    onRemove: () {},
                    horizontal: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MENU
// ============================================================

class MenuScreen extends StatefulWidget {
  final List<FoodItem> menu;
  final Map<String, int> cart;
  final Function(FoodItem) onAdd;
  final Function(FoodItem) onRemove;

  const MenuScreen({
    super.key,
    required this.menu,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String selectedCategory = 'All';
  String search = '';

  final categories = const [
    'All',
    'Breakfast',
    'Meals',
    'Snacks',
    'Drinks',
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = widget.menu.where((item) {
      final categoryMatch =
          selectedCategory == 'All' || item.category == selectedCategory;

      final searchMatch = search.isEmpty ||
          item.name.toLowerCase().contains(
                search.toLowerCase(),
              );

      return categoryMatch && searchMatch;
    }).toList();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF241A14),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Pick something good.',
                    style: TextStyle(
                      color: Color(0xFF766A62),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        search = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search food...',
                      prefixIcon: const Icon(
                        Icons.search,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final selected = category == selectedCategory;

                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                          selectedColor: const Color(0xFFE86A17),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF4C413A),
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FoodCard(
                    item: item,
                    quantity: widget.cart[item.id] ?? 0,
                    onAdd: () => widget.onAdd(item),
                    onRemove: () => widget.onRemove(item),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FOOD CARD
// ============================================================

class FoodCard extends StatelessWidget {
  final FoodItem item;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final bool horizontal;

  const FoodCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    // Reusable label shown only when the item is unavailable.
    Widget unavailableLabel() {
      if (item.available) {
        return const SizedBox.shrink();
      }

      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Text(
          'UNAVAILABLE',
          style: TextStyle(
            color: Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      );
    }

    if (horizontal) {
      return Container(
        width: 190,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 92,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE8D6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  item.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            unavailableLabel(),
            const SizedBox(height: 4),
            Text(
              '₹${item.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Color(0xFFE86A17),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A17),
                  minimumSize: const Size(0, 38),
                ),
                onPressed: onAdd,
                child: const Text('Add'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE8D6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                item.emoji,
                style: const TextStyle(fontSize: 40),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                unavailableLabel(),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF81766F),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹${item.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFFE86A17),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          quantity == 0
              ? IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE86A17),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEE2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '$quantity',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      IconButton(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}

// ============================================================
// CART
// ============================================================

class CartScreen extends StatefulWidget {
  final List<FoodItem> menu;
  final Map<String, int> cart;
  final Function(FoodItem) onAdd;
  final Function(FoodItem) onRemove;
  final double total;
  final VoidCallback onCheckoutComplete;
  final Future<bool> Function({
    required DateTime pickupAt,
    required PaymentMethod paymentMethod,
  }) onPlaceOrder;

  const CartScreen({
    super.key,
    required this.menu,
    required this.cart,
    required this.onAdd,
    required this.onRemove,
    required this.total,
    required this.onCheckoutComplete,
    required this.onPlaceOrder,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  double get currentTotal => widget.cart.entries.fold<double>(0, (sum, entry) {
        final matches = widget.menu.where((food) => food.id == entry.key);
        if (matches.isEmpty) return sum;
        return sum + matches.first.price * entry.value;
      });

  @override
  Widget build(BuildContext context) {
    final cartItems = widget.cart.entries.map((entry) {
      final item = widget.menu.firstWhere(
        (food) => food.id == entry.key,
      );

      return MapEntry(item, entry.value);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Cart',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: cartItems.isEmpty
          ? const Center(
              child: Text(
                'Your widget.cart is empty.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cartItems[index].key;
                      final quantity = cartItems[index].value;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 65,
                              height: 65,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE8D6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  item.emoji,
                                  style: const TextStyle(
                                    fontSize: 30,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '₹${item.price.toStringAsFixed(0)} × $quantity',
                                    style: const TextStyle(
                                      color: Color(0xFF766A62),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Subtotal: ₹${(item.price * quantity).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      color: Color(0xFFE86A17),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                widget.onRemove(item);
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.remove_circle_outline,
                              ),
                            ),
                            Text(
                              '$quantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                widget.onAdd(item);
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.add_circle_outline,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    18,
                    20,
                    24,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF766A62),
                              ),
                            ),
                            Text(
                              '₹${currentTotal.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFE86A17),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CheckoutScreen(
                                    total: currentTotal,
                                    onPlaceOrder: (pickupAt, paymentMethod) {
                                      return widget.onPlaceOrder(
                                        pickupAt: pickupAt,
                                        paymentMethod: paymentMethod,
                                      );
                                    },
                                  ),
                                ),
                              ).then((_) {
                                if (widget.cart.isEmpty) {
                                  widget.onCheckoutComplete();
                                }
                              });
                            },
                            child: const Text(
                              'Continue to Checkout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// CHECKOUT
// ============================================================

class CheckoutScreen extends StatefulWidget {
  final double total;
  final Future<bool> Function(
    DateTime pickupAt,
    PaymentMethod paymentMethod,
  ) onPlaceOrder;

  const CheckoutScreen({
    super.key,
    required this.total,
    required this.onPlaceOrder,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int step = 0;
  bool placingOrder = false;

  late DateTime selectedPickupAt;
  PaymentMethod paymentMethod = PaymentMethod.upi;

  List<DateTime> get pickupSlots {
    final now = DateTime.now();
    final earliest = now.add(const Duration(minutes: 15));
    List<DateTime> slotsFor(DateTime date) {
      final slots = <DateTime>[];
      for (var minute = 10 * 60; minute <= 17 * 60; minute += 15) {
        final slot = DateTime(
            date.year, date.month, date.day, minute ~/ 60, minute % 60);
        if (slot.isAfter(earliest) || slot.isAtSameMomentAs(earliest)) {
          slots.add(slot);
        }
      }
      return slots;
    }

    final today = DateTime(now.year, now.month, now.day);
    final todaysSlots = slotsFor(today);
    if (todaysSlots.isNotEmpty) return todaysSlots;
    return slotsFor(today.add(const Duration(days: 1)));
  }

  String get selectedPickup => _formatPickupDateTime(selectedPickupAt);

  @override
  void initState() {
    super.initState();
    selectedPickupAt = pickupSlots.first;
  }

  Future<void> next() async {
    if (step < 2) {
      setState(() {
        step++;
      });
      return;
    }

    setState(() => placingOrder = true);
    final success = await widget.onPlaceOrder(selectedPickupAt, paymentMethod);
    if (!mounted) return;
    setState(() => placingOrder = false);
    if (success) {
      showOrderPlaced();
    }
  }

  void showOrderPlaced() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          icon: Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFE6F7EA),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF2BA84A),
              size: 40,
            ),
          ),
          title: const Text(
            'Order Placed!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Your food will be ready around $selectedPickup.',
            textAlign: TextAlign.center,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE86A17),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('View My Orders'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            child: Row(
              children: [
                _StepIndicator(
                  number: 1,
                  label: 'Pickup',
                  active: step >= 0,
                ),
                _StepLine(active: step >= 1),
                _StepIndicator(
                  number: 2,
                  label: 'Payment',
                  active: step >= 1,
                ),
                _StepLine(active: step >= 2),
                _StepIndicator(
                  number: 3,
                  label: 'Confirm',
                  active: step >= 2,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildStep(),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              22,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Text(
                    '₹${widget.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE86A17),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                        ),
                      ),
                      onPressed: placingOrder ? null : next,
                      child: placingOrder
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(step == 2 ? 'Place Order' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    if (step == 0) {
      return _pickupStep();
    }

    if (step == 1) {
      return _paymentStep();
    }

    return _confirmStep();
  }

  Widget _pickupStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose pickup time',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose when you expect to reach the canteen.',
          style: TextStyle(
            color: Color(0xFF766A62),
          ),
        ),
        const SizedBox(height: 24),
        ...pickupSlots.map(
          (slot) {
            final selected = slot == selectedPickupAt;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() {
                    selectedPickupAt = slot;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFEEE2) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFE86A17)
                          : const Color(0xFFE9E2DC),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: selected
                            ? const Color(0xFFE86A17)
                            : const Color(0xFF766A62),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        _formatPickupDateTime(slot),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFFE86A17),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _paymentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select how you want to pay.',
          style: TextStyle(
            color: Color(0xFF766A62),
          ),
        ),
        const SizedBox(height: 24),
        PaymentOption(
          title: 'UPI',
          subtitle: 'Pay using a UPI app',
          icon: Icons.account_balance_wallet_outlined,
          selected: paymentMethod == PaymentMethod.upi,
          onTap: () {
            setState(() {
              paymentMethod = PaymentMethod.upi;
            });
          },
        ),
        const SizedBox(height: 12),
        PaymentOption(
          title: 'Cash at Canteen',
          subtitle: 'Pay when collecting your food',
          icon: Icons.payments_outlined,
          selected: paymentMethod == PaymentMethod.cash,
          onTap: () {
            setState(() {
              paymentMethod = PaymentMethod.cash;
            });
          },
        ),
        const SizedBox(height: 20),
        if (paymentMethod == PaymentMethod.upi)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFE86A17),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'UPI payment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'In the production version, this step will hand the payment to the selected UPI app and verify the transaction before confirming the order.',
                  style: TextStyle(
                    height: 1.4,
                    color: Color(0xFF6E625A),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _confirmStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review order',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 22),
        _ReviewRow(
          title: 'Pickup time',
          value: selectedPickup,
          icon: Icons.schedule,
        ),
        _ReviewRow(
          title: 'Payment',
          value: paymentMethod == PaymentMethod.upi ? 'UPI' : 'Cash at Canteen',
          icon: paymentMethod == PaymentMethod.upi
              ? Icons.account_balance_wallet_outlined
              : Icons.payments_outlined,
        ),
        _ReviewRow(
          title: 'Amount',
          value: '₹${widget.total.toStringAsFixed(0)}',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.flash_on_rounded,
                color: Color(0xFFE86A17),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your order will enter the canteen queue immediately after confirmation.',
                  style: TextStyle(
                    height: 1.4,
                    color: Color(0xFF6E625A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ORDERS
// ============================================================

class OrdersScreen extends StatelessWidget {
  final List<OrderModel> orders;
  final Function(OrderModel) onCancel;
  final Function(OrderModel) onDemoReady;

  const OrdersScreen({
    super.key,
    required this.orders,
    required this.onCancel,
    required this.onDemoReady,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: orders.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🛍️',
                      style: TextStyle(fontSize: 60),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No orders yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your orders will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF766A62),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                110,
              ),
              children: [
                const Text(
                  'My Orders',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${orders.length} order${orders.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF766A62),
                  ),
                ),
                const SizedBox(height: 20),
                ...orders.map(
                  (order) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: OrderCard(
                      order: order,
                      onCancel: order.status == OrderStatus.preparing
                          ? () => onCancel(order)
                          : null,
                      onDemoReady: null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onCancel;
  final VoidCallback? onDemoReady;

  const OrderCard({
    super.key,
    required this.order,
    this.onCancel,
    this.onDemoReady,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (order.orderNumber.isNotEmpty ? order.orderNumber : order.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              StatusChip(status: order.status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            order.items
                .map(
                  (item) => '${item.quantity}× ${item.name}',
                )
                .join(' • '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF766A62),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule,
                  size: 20,
                  color: Color(0xFFE86A17),
                ),
                const SizedBox(width: 9),
                Text(
                  'Pickup ${order.pickupTime}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null || onDemoReady != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onDemoReady != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDemoReady,
                      child: const Text(
                        'Demo: Mark Ready',
                      ),
                    ),
                  ),
                if (onCancel != null) ...[
                  if (onDemoReady != null) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC0392B),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ActiveOrderCard extends StatelessWidget {
  final OrderModel order;

  const ActiveOrderCard({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEE2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.restaurant,
              color: Color(0xFFE86A17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (order.orderNumber.isNotEmpty ? order.orderNumber : order.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pickup ${order.pickupTime}',
                  style: const TextStyle(
                    color: Color(0xFF766A62),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusChip(status: order.status),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE
// ============================================================

class ProfileScreen extends StatelessWidget {
  final String name;
  final String id;
  final String branch;
  final int orderCount;
  final VoidCallback onSignOut;
  final VoidCallback onManageAccount;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.id,
    required this.branch,
    required this.orderCount,
    required this.onSignOut,
    required this.onManageAccount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          24,
          20,
          110,
        ),
        children: [
          const Text(
            'Profile',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF2B211C),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 65,
                  height: 65,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE86A17),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  id,
                  style: const TextStyle(
                    color: Color(0xFFC9BCB3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _ProfileRow(
            icon: Icons.school_outlined,
            title: 'Branch',
            value: branch,
          ),
          _ProfileRow(
            icon: Icons.receipt_long_outlined,
            title: 'Orders placed',
            value: '$orderCount',
          ),
          _ProfileRow(
            icon: Icons.restaurant_outlined,
            title: 'Canteen',
            value: 'Main Canteen',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onManageAccount,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: Text(
              'Account options',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTTOM NAV
// ============================================================

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final int cartCount;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.cartCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: Colors.white,
      indicatorColor: const Color(0xFFFFE1CD),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        const NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu),
          label: 'Menu',
        ),
        NavigationDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.receipt_long_outlined),
              if (cartCount > 0)
                Positioned(
                  right: -7,
                  top: -7,
                  child: _CartBadge(count: cartCount),
                ),
            ],
          ),
          selectedIcon: const Icon(
            Icons.receipt_long,
          ),
          label: 'Orders',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _CartBadge extends StatelessWidget {
  final int count;

  const _CartBadge({
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 17,
        minHeight: 17,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFE86A17),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// COMPONENTS
// ============================================================

class PaymentOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const PaymentOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFEEE2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFE86A17) : const Color(0xFFE9E2DC),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE86A17)
                    : const Color(0xFFF4EFEA),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : const Color(0xFF5C5048),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF766A62),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFE86A17),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ReviewRow({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFE86A17),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF766A62),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int number;
  final String label;
  final bool active;

  const _StepIndicator({
    required this.number,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE86A17) : const Color(0xFFE4DDD7),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: active ? Colors.white : const Color(0xFF766A62),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;

  const _StepLine({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 15,
        ),
        color: active ? const Color(0xFFE86A17) : const Color(0xFFE4DDD7),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final OrderStatus status;

  const StatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    String text;

    switch (status) {
      case OrderStatus.preparing:
        background = const Color(0xFFFFEEE2);
        foreground = const Color(0xFFE86A17);
        text = 'Preparing';
        break;

      case OrderStatus.ready:
        background = const Color(0xFFE6F7EA);
        foreground = const Color(0xFF2BA84A);
        text = 'Ready';
        break;

      case OrderStatus.completed:
        background = const Color(0xFFE8EEF9);
        foreground = const Color(0xFF4267A8);
        text = 'Completed';
        break;

      case OrderStatus.cancelled:
        background = const Color(0xFFFBE9E7);
        foreground = const Color(0xFFC0392B);
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFFE86A17),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF766A62),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(
        label,
        icon,
      ).copyWith(
        hintText: hint,
      ),
    );
  }
}

InputDecoration _inputDecoration(
  String label,
  IconData icon,
) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(
        color: Color(0xFFE86A17),
        width: 1.5,
      ),
    ),
  );
}

String _formatClock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
}

String _formatPickupDateTime(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final label = date == today
      ? 'Today'
      : date == today.add(const Duration(days: 1))
          ? 'Tomorrow'
          : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  return '$label, ${_formatClock(value)}';
}

// ============================================================
// MODELS
// ============================================================

class FoodItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String emoji;
  final String description;
  final bool popular;
  final bool available;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.emoji,
    required this.description,
    required this.popular,
    this.available = true,
  });
}

class OrderLineItem {
  final String foodId;
  final String name;
  final double price;
  final int quantity;
  final String emoji;

  OrderLineItem({
    required this.foodId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.emoji,
  });

  Map<String, dynamic> toJson() {
    return {
      'foodId': foodId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'emoji': emoji,
    };
  }

  factory OrderLineItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return OrderLineItem(
      foodId: json['foodId'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      emoji: json['emoji'] ?? '🍽️',
    );
  }
}

class OrderModel {
  final String id; // Firestore document ID used for updates.
  final String orderNumber;
  final List<OrderLineItem> items;
  final double total;
  final String pickupTime;
  final PaymentMethod paymentMethod;
  OrderStatus status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    this.orderNumber = '',
    required this.items,
    required this.total,
    required this.pickupTime,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'pickupTime': pickupTime,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory OrderModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawItems = json['items'];

    final parsedItems = <OrderLineItem>[];

    if (rawItems is List) {
      for (final item in rawItems) {
        parsedItems.add(
          OrderLineItem.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      }
    }

    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? '',
      items: parsedItems,
      total: (json['total'] ?? 0).toDouble(),
      pickupTime: json['pickupTime'] ?? '',
      paymentMethod: PaymentMethod.values.firstWhere(
        (value) => value.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      status: OrderStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => OrderStatus.preparing,
      ),
      createdAt: DateTime.tryParse(
            json['createdAt'] ?? '',
          ) ??
          DateTime.now(),
    );
  }
}

enum PaymentMethod {
  upi,
  cash,
}

enum OrderStatus {
  preparing,
  ready,
  completed,
  cancelled,
}
