import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/canteen_order.dart';

/// Shared Firestore contract for student-created orders
/// and the canteen console.
class FirestoreOrderService {
  FirestoreOrderService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// Watches orders in newest-first order.
  Stream<List<CanteenOrder>> watchOrders() {
    return _orders.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => _fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  /// Updates an order using its internal Firestore document ID.
  ///
  /// Do not pass the customer-facing order number to this method.
  Future<void> updateStatus(
    String orderId,
    OrderStatus status,
  ) {
    return _orders.doc(orderId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  CanteenOrder _fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    final rawItems = data['items'];

    final items = rawItems is List
        ? rawItems.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);

            return OrderLine(
              name: (item['name'] ?? 'Menu item').toString(),
              quantity: _asInt(
                item['quantity'],
                fallback: 1,
              ),
              price: _asDouble(item['price']),
              emoji: (item['emoji'] ?? '🍽️').toString(),
            );
          }).toList()
        : <OrderLine>[];

    final pickupAt = _asDateTime(data['pickupAt']);
    final createdAt = _asDateTime(data['createdAt']) ?? DateTime.now();

    final statusText = (data['status'] ?? 'newOrder').toString();

    final status = OrderStatus.values.firstWhere(
      (value) => value.name == statusText,
      orElse: () => OrderStatus.newOrder,
    );

    final total = data['total'] is num
        ? (data['total'] as num).toDouble()
        : items.fold<double>(
            0,
            (runningTotal, item) => runningTotal + item.total,
          );

    final estimatedPrepMinutes = _asInt(
      data['estimatedPrepMinutes'],
      fallback: 10,
    );

    return CanteenOrder(
      // Internal database ID, used for status updates.
      id: documentId,

      // Display number saved in the order document, e.g. EC-104.
      // This service reads it; it does not generate it.
      orderNumber: (data['orderNumber'] ?? '').toString(),

      studentName: (data['studentName'] ?? 'Student').toString(),
      studentId: (data['studentId'] ?? '').toString(),
      items: items,
      createdAt: createdAt,
      total: total,
      pickupTime: (data['pickupTime'] ??
              (pickupAt == null ? 'Not specified' : _formatTime(pickupAt)))
          .toString(),
      pickupAt: pickupAt,
      paymentMethod: (data['paymentMethod'] ?? 'Not specified').toString(),
      status: status,
      note: (data['note'] ?? '').toString(),
      estimatedPrepMinutes: estimatedPrepMinutes,
    );
  }

  static int _asInt(
    dynamic value, {
    required int fallback,
  }) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
  }
}
