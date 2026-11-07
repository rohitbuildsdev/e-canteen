import 'package:cloud_firestore/cloud_firestore.dart';

class MenuItemRecord {
  const MenuItemRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.emoji,
    required this.description,
    required this.available,
    this.active = true,
  });

  final String id;
  final String name;
  final String category;
  final double price;
  final String emoji;
  final String description;
  final bool available;
  final bool active;

  factory MenuItemRecord.fromMap(String id, Map<String, dynamic> data) {
    final price = data['price'];
    return MenuItemRecord(
      id: id,
      name: (data['name'] ?? 'Untitled item').toString(),
      category: (data['category'] ?? 'Other').toString(),
      price: price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
      emoji: (data['emoji'] ?? '🍽️').toString(),
      description: (data['description'] ?? '').toString(),
      available: data['available'] != false,
      active: data['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'price': price,
        'emoji': emoji,
        'description': description,
        'available': available,
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class FirestoreMenuService {
  FirestoreMenuService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _menu =>
      _firestore.collection('menu_items');

  Stream<List<MenuItemRecord>> watchMenu() => _menu
      .orderBy('name')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => MenuItemRecord.fromMap(doc.id, doc.data()))
          .toList(growable: false));

  Future<void> seedDefaultsIfEmpty() async {
    final snapshot = await _menu.limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    const defaults = <({String name, String category, double price, String emoji, String description})>[
      (name: 'Idly', category: 'Breakfast', price: 30, emoji: '🥣', description: 'Soft steamed idlis served with chutney and sambar.'),
      (name: 'Masala Dosa', category: 'Breakfast', price: 55, emoji: '🥞', description: 'Crispy dosa filled with flavorful potato masala.'),
      (name: 'Vada', category: 'Breakfast', price: 35, emoji: '🍩', description: 'Crispy South Indian medu vada.'),
      (name: 'Veg Meals', category: 'Meals', price: 80, emoji: '🍛', description: 'Vegetarian meal with rice, curry and sides.'),
      (name: 'Fried Rice', category: 'Meals', price: 90, emoji: '🍚', description: 'Vegetable fried rice.'),
      (name: 'Veg Noodles', category: 'Meals', price: 85, emoji: '🍜', description: 'Noodles with fresh vegetables.'),
      (name: 'Samosa', category: 'Snacks', price: 20, emoji: '🥟', description: 'Crispy samosa with potato filling.'),
      (name: 'Veg Puff', category: 'Snacks', price: 25, emoji: '🥐', description: 'Flaky vegetable pastry.'),
      (name: 'Tea', category: 'Drinks', price: 15, emoji: '☕', description: 'Fresh hot tea.'),
      (name: 'Coffee', category: 'Drinks', price: 20, emoji: '☕', description: 'Hot filter coffee.'),
    ];
    final batch = _firestore.batch();
    for (final item in defaults) {
      final ref = _menu.doc();
      batch.set(ref, {
        'name': item.name, 'category': item.category, 'price': item.price,
        'emoji': item.emoji, 'description': item.description,
        'available': true, 'active': true,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> save(MenuItemRecord item) async {
    final data = item.toMap();
    if (item.id.isEmpty) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await _menu.add(data);
    } else {
      await _menu.doc(item.id).set(data, SetOptions(merge: true));
    }
  }

  Future<void> setAvailability(String id, bool available) =>
      _menu.doc(id).update({
        'available': available,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Soft-remove preserves the item for historical order references.
  Future<void> remove(String id) => _menu.doc(id).update({
        'active': false,
        'available': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}
