import 'package:flutter/material.dart';
import '../models/canteen_order.dart';

const brandOrange = Color(0xFFE85D2A);

class OrderCard extends StatelessWidget {
  const OrderCard(
      {super.key,
      required this.order,
      required this.onAdvance,
      required this.onCancel});
  final CanteenOrder order;
  final VoidCallback onAdvance;
  final VoidCallback onCancel;

  Color get statusColor => switch (order.status) {
        OrderStatus.newOrder => const Color(0xFFB86A12),
        OrderStatus.confirmed => const Color(0xFF3674C8),
        OrderStatus.preparing => const Color(0xFF986700),
        OrderStatus.ready => const Color(0xFF218653),
        OrderStatus.collected => const Color(0xFF68716A),
        OrderStatus.cancelled => const Color(0xFFC34B43),
      };

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _pickupGuidance() {
    final pickup = order.pickupAt;
    if (pickup == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final startBy =
        pickup.subtract(Duration(minutes: order.estimatedPrepMinutes));
    final minutesUntilPickup = pickup.difference(now).inMinutes;
    final Color color;
    final IconData icon;
    final String message;
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.collected) return const SizedBox.shrink();
    if (now.isAfter(pickup) && order.status != OrderStatus.ready) {
      color = const Color(0xFFC34B43);
      icon = Icons.warning_amber_rounded;
      message = 'Pickup time passed — prioritize this order';
    } else if (order.status == OrderStatus.ready && now.isBefore(pickup)) {
      color = const Color(0xFF3674C8);
      icon = Icons.schedule_rounded;
      message = 'Ready early — hold for ${order.pickupTime} pickup';
    } else if ((order.status == OrderStatus.newOrder ||
            order.status == OrderStatus.confirmed) &&
        now.isBefore(startBy)) {
      color = const Color(0xFF3674C8);
      icon = Icons.schedule_rounded;
      message =
          'Planned start: ${_formatTime(startBy)} · Pickup ${order.pickupTime}';
    } else if (order.status == OrderStatus.preparing && now.isBefore(startBy)) {
      color = const Color(0xFFB86A12);
      icon = Icons.info_outline_rounded;
      message = 'Preparation started ahead of the planned time';
    } else {
      color = const Color(0xFF218653);
      icon = Icons.timelapse_rounded;
      message = minutesUntilPickup <= 0
          ? 'Pickup due now'
          : 'Pickup in about $minutesUntilPickup min';
    }
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)))
        ]));
  }

  bool get waitingForPrepWindow {
    final pickup = order.pickupAt;
    return order.status == OrderStatus.confirmed &&
        pickup != null &&
        DateTime.now().isBefore(
            pickup.subtract(Duration(minutes: order.estimatedPrepMinutes)));
  }

  bool get waitingForPickupTime =>
      order.status == OrderStatus.preparing &&
      order.pickupAt != null &&
      DateTime.now().isBefore(order.pickupAt!);

  String get actionLabel => switch (order.status) {
        OrderStatus.newOrder => 'Accept order',
        OrderStatus.confirmed => waitingForPrepWindow
            ? 'Start at ${_formatTime(order.pickupAt!.subtract(Duration(minutes: order.estimatedPrepMinutes)))}'
            : 'Start preparing',
        OrderStatus.preparing =>
          waitingForPickupTime ? 'Ready at ${order.pickupTime}' : 'Mark ready',
        OrderStatus.ready => 'Confirm pickup',
        _ => 'No action',
      };

  @override
  Widget build(BuildContext context) {
    final canAdvance = order.isActive;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: brandOrange)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(order.displayOrderNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text('${order.studentName} • ${order.studentId}',
                          style: const TextStyle(
                              color: Color(0xFF777B75), fontSize: 12))
                    ])),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(99)),
                    child: Text(order.status.label,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 11))),
              ]),
              const SizedBox(height: 15),
              ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text('${item.quantity} × ${item.name}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600))),
                    Text('₹${item.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700))
                  ]))),
              if (order.note.isNotEmpty)
                Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4, bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(10)),
                    child: Text('Note: ${order.note}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF775A21)))),
              const Divider(height: 22),
              _pickupGuidance(),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule_rounded,
                          size: 16, color: Color(0xFF777B75)),
                      const SizedBox(width: 5),
                      Text('Pickup ${order.pickupTime}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF222821)))
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.payments_outlined,
                          size: 16, color: Color(0xFF777B75)),
                      const SizedBox(width: 5),
                      Text(order.paymentMethod,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF777B75)))
                    ]),
                    Text('Total ₹${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800))
                  ]),
              if (canAdvance) ...[
                const SizedBox(height: 14),
                Row(children: [
                  if (order.status == OrderStatus.newOrder ||
                      order.status == OrderStatus.confirmed)
                    TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel',
                            style: TextStyle(color: Color(0xFFC34B43)))),
                  const Spacer(),
                  FilledButton.icon(
                      onPressed: waitingForPrepWindow || waitingForPickupTime
                          ? null
                          : onAdvance,
                      icon: Icon(
                          order.status == OrderStatus.ready
                              ? Icons.check_circle_outline
                              : Icons.arrow_forward_rounded,
                          size: 17),
                      label: Text(actionLabel),
                      style: FilledButton.styleFrom(
                          backgroundColor: brandOrange,
                          foregroundColor: Colors.white))
                ])
              ],
            ])));
  }
}
