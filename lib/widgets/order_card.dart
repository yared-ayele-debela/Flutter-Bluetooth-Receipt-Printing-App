import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';     // 👈 ADD THIS


class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onViewDetails;
  final VoidCallback onPrint;

  const OrderCard({
    super.key,
    required this.order,
    required this.onViewDetails,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(order.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
    final formattedTime = DateFormat('hh:mm a').format(parsedDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(
          "Order #${order.id} • ${order.waiterName ?? "-"}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            "Total: ${order.grandTotal.toStringAsFixed(2)} ETB\n"
                "Date: $formattedDate • $formattedTime",
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              order.isPrinted ? Icons.print : Icons.print_disabled,
              color: order.isPrinted ? Colors.green : Colors.redAccent,
            ),
            const SizedBox(height: 4),
            Text(order.isPrinted ? "Printed" : "Not Printed",
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        onTap: onViewDetails,
      ),
    );
  }
}
