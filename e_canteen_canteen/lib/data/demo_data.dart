import '../models/canteen_order.dart';

class DemoMenuItem {
  const DemoMenuItem(
      {required this.name,
      required this.category,
      required this.price,
      required this.emoji});
  final String name;
  final String category;
  final double price;
  final String emoji;
}

const demoMenu = <DemoMenuItem>[
  DemoMenuItem(name: 'Idly', category: 'Breakfast', price: 30, emoji: '🥣'),
  DemoMenuItem(
      name: 'Masala Dosa', category: 'Breakfast', price: 55, emoji: '🥞'),
  DemoMenuItem(name: 'Vada', category: 'Breakfast', price: 35, emoji: '🍩'),
  DemoMenuItem(name: 'Veg Meals', category: 'Meals', price: 80, emoji: '🍛'),
  DemoMenuItem(name: 'Fried Rice', category: 'Meals', price: 90, emoji: '🍚'),
  DemoMenuItem(name: 'Veg Noodles', category: 'Meals', price: 85, emoji: '🍜'),
  DemoMenuItem(name: 'Samosa', category: 'Snacks', price: 20, emoji: '🥟'),
  DemoMenuItem(name: 'Veg Puff', category: 'Snacks', price: 25, emoji: '🥐'),
  DemoMenuItem(name: 'Tea', category: 'Drinks', price: 15, emoji: '☕'),
  DemoMenuItem(name: 'Coffee', category: 'Drinks', price: 20, emoji: '☕'),
];

List<CanteenOrder> buildDemoOrders() {
  final now = DateTime.now();
  return [
    CanteenOrder(
        id: 'EC-10421',
        studentName: 'Aarav Kumar',
        studentId: '24A81A0501',
        items: const [
          OrderLine(name: 'Masala Dosa', quantity: 1, price: 55, emoji: '🥞'),
          OrderLine(name: 'Tea', quantity: 1, price: 15, emoji: '☕')
        ],
        total: 70,
        pickupTime: formatPickupTime(now.add(const Duration(minutes: 20))),
        pickupAt: now.add(const Duration(minutes: 20)),
        paymentMethod: 'UPI (pending)',
        status: OrderStatus.newOrder),
    CanteenOrder(
        id: 'EC-10420',
        studentName: 'Sravya Reddy',
        studentId: '24A81A0502',
        items: const [
          OrderLine(name: 'Veg Meals', quantity: 1, price: 80, emoji: '🍛')
        ],
        total: 80,
        pickupTime: formatPickupTime(now.add(const Duration(minutes: 8))),
        pickupAt: now.add(const Duration(minutes: 8)),
        paymentMethod: 'Cash',
        status: OrderStatus.confirmed),
    CanteenOrder(
        id: 'EC-10419',
        studentName: 'Sai Teja',
        studentId: '24A81A0503',
        items: const [
          OrderLine(name: 'Samosa', quantity: 2, price: 20, emoji: '🥟')
        ],
        total: 40,
        pickupTime: formatPickupTime(now.add(const Duration(minutes: 3))),
        pickupAt: now.add(const Duration(minutes: 3)),
        paymentMethod: 'UPI (pending)',
        status: OrderStatus.preparing),
    CanteenOrder(
        id: 'EC-10418',
        studentName: 'Kavya Sri',
        studentId: '24A81A0504',
        items: const [
          OrderLine(name: 'Coffee', quantity: 2, price: 20, emoji: '☕')
        ],
        total: 40,
        pickupTime: formatPickupTime(now.subtract(const Duration(minutes: 2))),
        pickupAt: now.subtract(const Duration(minutes: 2)),
        paymentMethod: 'Cash',
        status: OrderStatus.ready),
    CanteenOrder(
        id: 'EC-10417',
        studentName: 'Manoj',
        studentId: '24A81A0505',
        items: const [
          OrderLine(name: 'Idly', quantity: 2, price: 30, emoji: '🥣')
        ],
        total: 60,
        pickupTime: formatPickupTime(now.subtract(const Duration(minutes: 15))),
        pickupAt: now.subtract(const Duration(minutes: 15)),
        paymentMethod: 'Cash',
        status: OrderStatus.collected),
  ];
}
