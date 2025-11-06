import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/printer_service.dart';

class OrderDetailModal extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onPrinted; // callback to parent to refresh

  const OrderDetailModal({super.key, required this.order, this.onPrinted});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 12),
            Text("Order #${order.referenceCode}",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Customer: ${order.customerName}"),
                Text("Total: ${order.grandTotal.toStringAsFixed(2)} ETB"),
              ],
            ),
            const Divider(),
            SizedBox(
              height: 240,
              child: ListView.separated(
                itemCount: order.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final item = order.items[i];
                  return ListTile(
                    title: Text(item.productName),
                    trailing: Text("${item.quantity} x ${item.subtotal.toStringAsFixed(2)}"),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await PrinterService().printOrder(context, order);
                      if (onPrinted != null) onPrinted!();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
