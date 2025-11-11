// order_detail_modal.dart
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/printer_service.dart';

class OrderDetailModal extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onPrinted;

  const OrderDetailModal({super.key, required this.order, this.onPrinted});

  // Smart print: reuse saved printer or select one
  Future<void> _smartPrint(BuildContext context) async {
    final printerService = PrinterService();
    final savedAddress = await printerService.getSavedPrinterAddress();

    if (savedAddress != null && savedAddress.isNotEmpty) {
      await printerService.printOrderSmart(context, order);
    } else {
      final device = await printerService.selectAndSavePrinter(context);
      if (device == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printing cancelled')),
          );
        }
        return;
      }
      await printerService.printOrderSmart(context, order);
    }

    onPrinted?.call();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),

            // Title + Printer Status
            FutureBuilder<Map<String, String?>>(
              future: Future.wait([
                PrinterService().getSavedPrinterAddress(),
                PrinterService().getSavedPrinterName(),
              ]).then((list) => {'address': list[0], 'name': list[1]}),
              builder: (context, snapshot) {
                final isConnected = snapshot.data?['address']?.isNotEmpty == true;
                final printerName = snapshot.data?['name'] ?? 'Unknown Printer';

                return Column(
                  children: [
                    Text(
                      "Order #${order.referenceCode}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.print,
                          size: 16,
                          color: isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isConnected
                              ? 'Connected: $printerName'
                              : 'No printer connected',
                          style: TextStyle(
                            fontSize: 13,
                            color: isConnected ? Colors.green : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 10),

            // Customer & Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Customer: ${order.customerName}"),
                Text("Total: ${order.grandTotal.toStringAsFixed(2)} ETB"),
              ],
            ),
            const Divider(),

            // Items list
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

            // Print Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _smartPrint(context),
                    icon: const Icon(Icons.print),
                    label: const Text("Print"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
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