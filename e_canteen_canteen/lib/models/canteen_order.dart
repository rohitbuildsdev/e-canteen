enum OrderStatus {
  newOrder,
  confirmed,
  preparing,
  ready,
  collected,
  cancelled,
}

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.newOrder => 'New',
        OrderStatus.confirmed => 'Confirmed',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => 'Ready',
        OrderStatus.collected => 'Collected',
        OrderStatus.cancelled => 'Cancelled',
      };
}

class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.price,
    this.emoji = '🍽️',
  });

  final String name;
  final int quantity;
  final double price;
  final String emoji;

  double get total => quantity * price;
}

class CanteenOrder {
  CanteenOrder({
    required this.id,
    required this.studentName,
    required this.studentId,
    required this.items,
    required this.total,
    required this.pickupTime,
    required this.paymentMethod,
    required this.status,
    this.orderNumber = '',
    this.note = '',
    this.pickupAt,
    this.estimatedPrepMinutes = 10,
    this.createdAt,
  });

  /// Internal Firestore document ID. Keep this for database operations.
  final String id;

  /// Customer-facing order number, e.g. EC-104.
  final String orderNumber;

  final String studentName;
  final String studentId;
  final List<OrderLine> items;
  final double total;
  final String pickupTime;
  final String paymentMethod;
  OrderStatus status;
  final String note;
  final DateTime? pickupAt;
  final int estimatedPrepMinutes;
  final DateTime? createdAt;

  /// Safe display fallback for older orders without an assigned number.
  String get displayOrderNumber =>
      orderNumber.isNotEmpty ? orderNumber : 'Number pending';

  bool get isActive =>
      status != OrderStatus.collected && status != OrderStatus.cancelled;
}

String formatPickupTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;

  return '$hour:${time.minute.toString().padLeft(2, '0')} '
      '${time.hour >= 12 ? 'PM' : 'AM'}';
}
