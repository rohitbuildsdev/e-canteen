import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firestore_order_service.dart';
import '../services/firestore_menu_service.dart';
import '../models/canteen_order.dart';
import '../widgets/order_card.dart';
import '../widgets/metric_card.dart';

const ink = Color(0xFF222821);
const muted = Color(0xFF777B75);
const brandOrange = Color(0xFFE85D2A);

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int tab = 0;
  final List<CanteenOrder> orders = [];
  final FirestoreOrderService _orderService = FirestoreOrderService();
  final FirestoreMenuService _menuService = FirestoreMenuService();
  StreamSubscription<List<CanteenOrder>>? _ordersSubscription;
  bool _ordersLoading = true;
  String? _ordersError;

  @override
  void initState() {
    super.initState();
    _menuService.seedDefaultsIfEmpty().catchError((Object error) {
      debugPrint('Menu seed skipped: $error');
    });
    _ordersSubscription = _orderService.watchOrders().listen(
      (liveOrders) {
        if (!mounted) return;
        setState(() {
          orders
            ..clear()
            ..addAll(liveOrders);
          _ordersLoading = false;
          _ordersError = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _ordersLoading = false;
          _ordersError = error.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  final Set<String> unavailableItems = {};
  String query = '';
  String orderFilter = 'Active';
  final String staffName = 'Canteen Staff';
  final String canteenName = 'Hostel Canteen';

  int get activeCount => orders.where((o) => o.isActive).length;
  int get newCount =>
      orders.where((o) => o.status == OrderStatus.newOrder).length;
  int get readyCount =>
      orders.where((o) => o.status == OrderStatus.ready).length;
  double get collectedRevenue => orders
      .where((o) => o.status == OrderStatus.collected)
      .fold(0, (sum, o) => sum + o.total);

  String get searchHint => switch (tab) {
        0 => 'Search recent orders...',
        1 => 'Search orders, students or food...',
        2 => 'Search menu items or categories...',
        _ => 'Search report metrics...',
      };

  Future<void> advance(CanteenOrder order) async {
    final pickup = order.pickupAt;
    if (pickup != null &&
        order.status == OrderStatus.confirmed &&
        DateTime.now().isBefore(
            pickup.subtract(Duration(minutes: order.estimatedPrepMinutes)))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Preparation can start at ${formatPickupTime(pickup.subtract(Duration(minutes: order.estimatedPrepMinutes)))}.'),
      ));
      return;
    }
    if (pickup != null &&
        order.status == OrderStatus.preparing &&
        DateTime.now().isBefore(pickup)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('This order is scheduled for pickup at ${order.pickupTime}.'),
      ));
      return;
    }

    final nextStatus = switch (order.status) {
      OrderStatus.newOrder => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.preparing,
      OrderStatus.preparing => OrderStatus.ready,
      OrderStatus.ready => OrderStatus.collected,
      OrderStatus.collected || OrderStatus.cancelled => null,
    };
    if (nextStatus == null) return;

    try {
      await _orderService.updateStatus(order.id, nextStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${order.displayOrderNumber}: ${nextStatus.label}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update order: $error')),
        );
      }
    }
  }

  Future<void> cancel(CanteenOrder order) async {
    try {
      await _orderService.updateStatus(order.id, OrderStatus.cancelled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not cancel order: $error')),
        );
      }
    }
  }

  void runMetricAction(String action) {
    switch (action) {
      case 'View active orders':
      case 'View new orders':
      case 'View ready orders':
        setState(() {
          tab = 1;
          orderFilter = action == 'View active orders'
              ? 'Active'
              : action == 'View new orders'
                  ? 'New'
                  : 'Ready';
          query = '';
        });
      case 'View all orders':
        setState(() {
          tab = 1;
          orderFilter = 'All';
          query = '';
        });
      case 'View collected orders':
        setState(() {
          tab = 1;
          orderFilter = 'Completed';
          query = '';
        });
      case 'View report details':
      case 'View sample transactions':
        setState(() {
          tab = 3;
          query = '';
        });
      case 'Review pending pickups':
        setState(() {
          tab = 1;
          orderFilter = 'Ready';
          query = '';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pages = [_dashboard(), _orders(), _menu(), _analytics()];
    return Scaffold(
      body: SafeArea(
          child: Row(children: [
        if (wide) _sidebar(),
        Expanded(
            child: Column(children: [
          _topBar(wide),
          if (_ordersError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Firestore connection / permission issue: $_ordersError',
                style: const TextStyle(color: Color(0xFF9C3B20), fontSize: 12),
              ),
            )
          else if (_ordersLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]))),
        ])),
      ])),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (v) => setState(() {
                    tab = v;
                    query = '';
                  }),
              destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.grid_view_rounded), label: 'Overview'),
                  NavigationDestination(
                      icon: Icon(Icons.receipt_long_rounded), label: 'Orders'),
                  NavigationDestination(
                      icon: Icon(Icons.restaurant_menu_rounded), label: 'Menu'),
                  NavigationDestination(
                      icon: Icon(Icons.bar_chart_rounded), label: 'Reports'),
                ]),
    );
  }

  Widget _sidebar() => Container(
      width: 238,
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 18),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEAEAE5)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBDD),
                  borderRadius: BorderRadius.circular(14)),
              child:
                  const Icon(Icons.ramen_dining_rounded, color: brandOrange)),
          const SizedBox(width: 10),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('E-Canteen',
                    style:
                        TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                Text('Canteen console',
                    style: TextStyle(fontSize: 11, color: muted))
              ]))
        ]),
        const SizedBox(height: 34),
        const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 10),
            child: Text('CANTEEN WORKSPACE',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: muted,
                    letterSpacing: 1.2))),
        _navTile(0, Icons.grid_view_rounded, 'Overview'),
        _navTile(1, Icons.receipt_long_rounded, 'Orders', badge: newCount),
        _navTile(2, Icons.restaurant_menu_rounded, 'Menu'),
        _navTile(3, Icons.bar_chart_rounded, 'Reports'),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F7F4),
              borderRadius: BorderRadius.circular(15)),
          child: const Row(children: [
            Icon(Icons.wifi_rounded, color: Color(0xFF218653), size: 18),
            SizedBox(width: 8),
            Expanded(
                child: Text('Live order sync',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
        ),
      ]));

  Widget _navTile(int index, IconData icon, String label, {int badge = 0}) {
    final selected = tab == index;
    return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: ListTile(
            selected: selected,
            selectedTileColor: const Color(0xFFFFF0E8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            onTap: () => setState(() {
                  tab = index;
                  query = '';
                }),
            leading:
                Icon(icon, color: selected ? brandOrange : muted, size: 21),
            title: Text(label,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? brandOrange : ink,
                    fontSize: 13)),
            trailing: badge > 0
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: brandOrange,
                        borderRadius: BorderRadius.circular(99)),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)))
                : null,
            dense: true));
  }

  Widget _topBar(bool wide) => Padding(
      padding: EdgeInsets.fromLTRB(wide ? 30 : 18, 18, wide ? 30 : 18, 14),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(['Overview', 'Order queue', 'Menu management', 'Reports'][tab],
              style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.6)),
          const SizedBox(height: 3),
          const Text('Hostel canteen • Live workspace',
              style: TextStyle(fontSize: 12, color: muted))
        ])),
        if (wide)
          SizedBox(
              width: 250,
              child: TextField(
                  key: const ValueKey('global-search'),
                  onChanged: (v) => setState(() => query = v),
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: searchHint,
                      isDense: true,
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () => setState(() => query = ''),
                              icon: const Icon(Icons.close_rounded))))),
        const SizedBox(width: 8),
        Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEAEAE5))),
            child: IconButton(
                tooltip: 'Notifications',
                onPressed: _showNotifications,
                icon: Stack(clipBehavior: Clip.none, children: [
                  const Icon(Icons.notifications_none_rounded, size: 20),
                  if (newCount + readyCount > 0)
                    Positioned(
                        right: -5,
                        top: -4,
                        child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: brandOrange, shape: BoxShape.circle)))
                ]))),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
            tooltip: 'Staff profile',
            onSelected: (value) {
              if (value == 'profile') _showProfile();
              if (value == 'signout') _showDemoSignOut();
            },
            itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Staff profile'),
                          contentPadding: EdgeInsets.zero)),
                  PopupMenuItem(
                      value: 'signout',
                      child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Sign out (demo)'),
                          contentPadding: EdgeInsets.zero))
                ],
            child: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBDD),
                child: Text('C',
                    style: TextStyle(
                        color: brandOrange, fontWeight: FontWeight.w900)))),
      ]));

  void _showNotifications() {
    final alerts = <CanteenOrder>[
      ...orders.where((o) => o.status == OrderStatus.newOrder),
      ...orders.where((o) => o.status == OrderStatus.ready),
    ];
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Notifications'),
                content: SizedBox(
                    width: 420,
                    child: alerts.isEmpty
                        ? const Text(
                            'You’re all caught up. No new orders or pending pickups.')
                        : ListView(
                            shrinkWrap: true,
                            children: alerts
                                .map((o) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(o.status == OrderStatus.ready ? Icons.notifications_active_outlined : Icons.mark_email_unread_outlined, color: brandOrange),
                                    title: Text('${o.displayOrderNumber} • ${o.status.label}'),
                                    subtitle: Text('${o.studentName} · Pickup ${o.pickupTime}'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        tab = 1;
                                        orderFilter =
                                            o.status == OrderStatus.ready
                                                ? 'Ready'
                                                : 'New';
                                        query = o.displayOrderNumber;
                                      });
                                    }))
                                .toList())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ]));
  }

  void _showProfile() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Staff profile'),
              content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline),
                        title: Text('Canteen Staff'),
                        subtitle: Text('Demo staff account')),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.storefront_outlined),
                        title: Text('Hostel Canteen'),
                        subtitle: Text('Canteen workspace'))
                  ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ]));

  void _showDemoSignOut() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Demo account'),
              content: const Text(
                  'This session uses Firebase Authentication. Staff sign-out will be added with the staff login flow.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it'))
              ]));

  bool _matchesOrder(CanteenOrder o) =>
      '${o.displayOrderNumber} ${o.id} ${o.studentName} ${o.studentId} ${o.items.map((i) => i.name).join(' ')} ${o.status.label}'
          .toLowerCase()
          .contains(query.trim().toLowerCase());

  Widget _dashboard() {
    final recent = orders
        .where((o) => o.isActive && (query.trim().isEmpty || _matchesOrder(o)))
        .take(5)
        .toList();
    final cards = [
      MetricCard(
          title: 'Active orders',
          value: '$activeCount',
          subtitle: 'Currently in the queue',
          icon: Icons.receipt_long_rounded,
          tint: brandOrange,
          actions: const ['View active orders', 'View all orders'],
          onAction: runMetricAction),
      MetricCard(
          title: 'New orders',
          value: '$newCount',
          subtitle: 'Waiting for acceptance',
          icon: Icons.mark_email_unread_outlined,
          tint: const Color(0xFF3674C8),
          actions: const ['View new orders', 'View all orders'],
          onAction: runMetricAction),
      MetricCard(
          title: 'Ready for pickup',
          value: '$readyCount',
          subtitle: 'Students to notify',
          icon: Icons.notifications_active_outlined,
          tint: const Color(0xFF218653),
          actions: const ['View ready orders', 'Review pending pickups'],
          onAction: runMetricAction),
      MetricCard(
          title: 'Collected value',
          value: '₹${collectedRevenue.toStringAsFixed(0)}',
          subtitle: 'Collected orders',
          icon: Icons.currency_rupee_rounded,
          tint: const Color(0xFF8A62C7),
          actions: const ['View report details', 'View sample transactions'],
          onAction: runMetricAction),
    ];
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          if (MediaQuery.sizeOf(context).width < 900) _compactSearch(),
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF252B25), Color(0xFF424B3D)]),
                  borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('SERVICE STATUS',
                          style: TextStyle(
                              color: Color(0xFFC5C9C0),
                              fontSize: 10,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      const Text('Lunch service is live',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text('$activeCount active orders need attention.',
                          style: const TextStyle(
                              color: Color(0xFFD9DDD5), fontSize: 13)),
                      const SizedBox(height: 15),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: Color(0xFF6FE0A2),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 7),
                        const Text('OPEN • DEMO',
                            style: TextStyle(
                                color: Color(0xFF9DEAB9),
                                fontWeight: FontWeight.w800,
                                fontSize: 11))
                      ])
                    ])),
                const SizedBox(width: 10),
                const Icon(Icons.ramen_dining_rounded,
                    color: Color(0xFFBBC5B2), size: 58)
              ])),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final count = box.maxWidth > 800
                ? 4
                : box.maxWidth > 500
                    ? 2
                    : 1;
            return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: count == 1
                    ? 1.75
                    : count == 2
                        ? 1.45
                        : 1.25,
                children: cards);
          }),
          const SizedBox(height: 25),
          _sectionHeader(
              query.isEmpty
                  ? 'Orders needing attention'
                  : 'Matching recent orders',
              'View all',
              () => setState(() {
                    tab = 1;
                    orderFilter = 'Active';
                  })),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            _empty('No matching active orders',
                'Try a different search or open all orders.')
          else
            ...recent.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrderCard(
                    order: o,
                    onAdvance: () => advance(o),
                    onCancel: () => cancel(o)))),
        ]);
  }

  Widget _compactSearch() => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: searchHint,
              isDense: true,
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => query = ''),
                      icon: const Icon(Icons.close_rounded)))));

  Widget _orders() {
    final filtered = orders.where((o) {
      final matchesQuery = query.trim().isEmpty || _matchesOrder(o);
      final matchesFilter = switch (orderFilter) {
        'Active' => o.isActive,
        'New' => o.status == OrderStatus.newOrder,
        'Ready' => o.status == OrderStatus.ready,
        'Completed' => o.status == OrderStatus.collected,
        'Cancelled' => o.status == OrderStatus.cancelled,
        _ => true
      };
      return matchesQuery && matchesFilter;
    }).toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          if (MediaQuery.sizeOf(context).width < 900) _compactSearch(),
          Row(children: [
            Expanded(
                child: Text('${filtered.length} orders',
                    style: const TextStyle(color: muted, fontSize: 13))),
            DropdownButton<String>(
                value: orderFilter,
                underline: const SizedBox.shrink(),
                items: const [
                  'Active',
                  'All',
                  'New',
                  'Ready',
                  'Completed',
                  'Cancelled'
                ]
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => orderFilter = v);
                })
          ]),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            _empty('No matching orders', 'Try another search or status filter.')
          else
            ...filtered.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OrderCard(
                    order: o,
                    onAdvance: () => advance(o),
                    onCancel: () => cancel(o)))),
        ]);
  }

  Future<void> _editMenuItem({MenuItemRecord? existing}) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final category =
        TextEditingController(text: existing?.category ?? 'Breakfast');
    final price = TextEditingController(
        text: existing == null ? '' : existing.price.toStringAsFixed(0));
    final emoji = TextEditingController(text: existing?.emoji ?? '🍽️');
    final description =
        TextEditingController(text: existing?.description ?? '');
    var available = existing?.available ?? true;
    final formKey = GlobalKey<FormState>();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add menu item' : 'Edit menu item'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Food name'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a name'
                          : null),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter a category'
                          : null),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Price (₹)'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        return n == null || n <= 0
                            ? 'Enter a price above zero'
                            : null;
                      }),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: emoji,
                      decoration:
                          const InputDecoration(labelText: 'Emoji / icon')),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: description,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Available to students'),
                      value: available,
                      onChanged: (v) => setDialogState(() => available = v)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate())
                    Navigator.pop(dialogContext, true);
                },
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (save == true) {
      try {
        await _menuService.save(MenuItemRecord(
          id: existing?.id ?? '',
          name: name.text.trim(),
          category: category.text.trim(),
          price: double.parse(price.text.trim()),
          emoji: emoji.text.trim().isEmpty ? '🍽️' : emoji.text.trim(),
          description: description.text.trim(),
          available: available,
          active: true,
        ));
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  existing == null ? 'Menu item added' : 'Menu item updated')));
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not save menu item: $error')));
      }
    }
    name.dispose();
    category.dispose();
    price.dispose();
    emoji.dispose();
    description.dispose();
  }

  Future<void> _removeMenuItem(MenuItemRecord item) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('Remove menu item?'),
              content: Text(
                  '${item.name} will no longer appear in the active student menu. Existing orders will remain unchanged.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('Keep item')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('Remove'))
              ],
            ));
    if (confirmed != true) return;
    try {
      await _menuService.remove(item.id);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Menu item removed from active menu')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not remove item: $error')));
    }
  }

  Widget _menu() {
    return StreamBuilder<List<MenuItemRecord>>(
      stream: _menuService.watchMenu(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return ListView(padding: const EdgeInsets.all(22), children: [
            Text('Could not load menu: ${snapshot.error}',
                style: const TextStyle(color: Color(0xFFC34B43)))
          ]);
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final allItems = snapshot.data!.where((item) => item.active).toList();
        final items = allItems
            .where((item) => (query.trim().isEmpty ||
                '${item.name} ${item.category} ${item.price}'
                    .toLowerCase()
                    .contains(query.trim().toLowerCase())))
            .toList();
        return ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            children: [
              if (MediaQuery.sizeOf(context).width < 900) _compactSearch(),
              Row(children: [
                const Expanded(
                    child: Text('Menu items',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800))),
                Text('${items.length} shown • ${allItems.length} total',
                    style: const TextStyle(color: muted, fontSize: 12))
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Changes sync to the student app through Firestore. Removed items are archived so past orders keep their original details.',
                  style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
              const SizedBox(height: 12),
              Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                      onPressed: () => _editMenuItem(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add item'))),
              const SizedBox(height: 14),
              if (items.isEmpty)
                _empty('No menu items yet',
                    'Add your first item, or check the search field.')
              else
                ...items.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3EA),
                                  borderRadius: BorderRadius.circular(13)),
                              child: Text(item.emoji,
                                  style: const TextStyle(fontSize: 23))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text(item.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                    '${item.category} • ${item.available ? 'Available' : 'Unavailable'}',
                                    style: TextStyle(
                                        color: item.available
                                            ? muted
                                            : const Color(0xFFC34B43),
                                        fontSize: 12)),
                                if (item.description.isNotEmpty)
                                  Text(item.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: muted, fontSize: 11))
                              ])),
                          const SizedBox(width: 6),
                          Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${item.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900)),
                                SizedBox(
                                    height: 34,
                                    child: Switch(
                                        value: item.available,
                                        activeThumbColor:
                                            const Color(0xFF218653),
                                        onChanged: (value) async {
                                          try {
                                            await _menuService.setAvailability(
                                                item.id, value);
                                          } catch (error) {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Could not update availability: $error')));
                                          }
                                        })),
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(
                                      tooltip: 'Edit item',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _editMenuItem(existing: item),
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 19)),
                                  IconButton(
                                      tooltip: 'Remove item',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _removeMenuItem(item),
                                      icon: const Icon(Icons.delete_outline,
                                          size: 19, color: Color(0xFFC34B43)))
                                ])
                              ]),
                        ]))))
            ]);
      },
    );
  }

  Widget _analytics() {
    final reportCards = <({
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color tint
    })>[
      (
        title: 'Orders created',
        value: '${orders.length}',
        subtitle: 'Live Firestore orders',
        icon: Icons.receipt_long_outlined,
        tint: brandOrange
      ),
      (
        title: 'Collected',
        value:
            '${orders.where((o) => o.status == OrderStatus.collected).length}',
        subtitle: 'Marked picked up',
        icon: Icons.check_circle_outline,
        tint: const Color(0xFF218653)
      ),
      (
        title: 'Cancelled',
        value:
            '${orders.where((o) => o.status == OrderStatus.cancelled).length}',
        subtitle: 'Cancelled orders',
        icon: Icons.cancel_outlined,
        tint: const Color(0xFFC34B43)
      ),
      (
        title: 'Collected value',
        value: '₹${collectedRevenue.toStringAsFixed(0)}',
        subtitle: 'Based on collected orders',
        icon: Icons.currency_rupee_rounded,
        tint: const Color(0xFF8A62C7)
      ),
    ]
        .where((item) =>
            query.trim().isEmpty ||
            '${item.title} ${item.value} ${item.subtitle}'
                .toLowerCase()
                .contains(query.trim().toLowerCase()))
        .toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: [
          if (MediaQuery.sizeOf(context).width < 900) _compactSearch(),
          const Text('A live view of order activity from Firestore.',
              style: TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 16),
          if (reportCards.isEmpty)
            _empty('No matching report metrics',
                'Search for orders, collected value or cancellations.')
          else
            LayoutBuilder(builder: (context, box) {
              final count = box.maxWidth > 650 ? 2 : 1;
              return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: count,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: count == 1 ? 2.1 : 1.5,
                  children: reportCards
                      .map((item) => MetricCard(
                          title: item.title,
                          value: item.value,
                          subtitle: item.subtitle,
                          icon: item.icon,
                          tint: item.tint,
                          actions: const [
                            'View all orders',
                            'View sample transactions'
                          ],
                          onAction: runMetricAction))
                      .toList());
            }),
          const SizedBox(height: 18),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pilot metrics to track',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 12),
                        ...[
                          'Average order preparation time',
                          'Orders ready before pickup slot',
                          'Order accuracy / missing items',
                          'Queue waiting time during breaks',
                          'Student and staff feedback'
                        ]
                            .where((s) =>
                                query.trim().isEmpty ||
                                s
                                    .toLowerCase()
                                    .contains(query.trim().toLowerCase()))
                            .map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: Color(0xFF218653), size: 18),
                                  const SizedBox(width: 9),
                                  Expanded(
                                      child: Text(s,
                                          style: const TextStyle(fontSize: 13)))
                                ])))
                      ]))),
        ]);
  }

  Widget _sectionHeader(String title, String action, VoidCallback onTap) =>
      Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16))),
        TextButton(
            onPressed: onTap,
            child: Text(action,
                style: const TextStyle(
                    color: brandOrange, fontWeight: FontWeight.w800)))
      ]);
  Widget _empty(String title, String subtitle) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: Column(children: [
        const Icon(Icons.inbox_outlined, size: 42, color: Color(0xFF9DA19A)),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 5),
        Text(subtitle,
            style: const TextStyle(color: muted), textAlign: TextAlign.center)
      ]));
}
