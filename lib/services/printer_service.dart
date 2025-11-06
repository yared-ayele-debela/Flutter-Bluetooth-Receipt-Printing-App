import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'api_service.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

class PrinterService {
  final ApiService api = ApiService();

  /// Print order using ESC/POS bytes (simplest & works on most printers)
  Future<void> printOrder(BuildContext context, OrderModel order) async {
    try {
      // ✅ Select device
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) return;

      final DateFormat df = DateFormat('yyyy-MM-dd HH:mm');

      // ✅ Build receipt text
      final List<String> lines = [];
      lines.add('      MY SHOP NAME');
      lines.add('    Address Line 1');
      lines.add('    Phone: +251 9xx xxx xxx');
      lines.add('--------------------------------');
      lines.add('Ref: ${order.referenceCode}');
      lines.add('Order: #${order.id}');
      lines.add('Customer: ${order.customerName}');
      lines.add('Waiter: ${order.waiterName ?? "-"}');
      lines.add('Date: ${order.date.isNotEmpty ? order.date : df.format(DateTime.now())}');
      lines.add('--------------------------------');
      lines.add('Item                 QTY   Total');
      lines.add('--------------------------------');

      for (var it in order.items) {
        final name = it.productName.length > 18 ? it.productName.substring(0, 18) : it.productName;
        final qty = it.quantity.toString();
        final total = it.subtotal.toStringAsFixed(2);
        lines.add(name.padRight(18) + qty.padLeft(4) + total.padLeft(9));
      }

      lines.add('--------------------------------');
      lines.add('Grand Total:'.padRight(20) + order.grandTotal.toStringAsFixed(2).padLeft(11));
      lines.add('\nThank you for your purchase!\n\n\n');

      // ✅ Convert to bytes (UTF8)
      final Uint8List bytes = Uint8List.fromList(lines.join('\n').codeUnits);

    await FlutterBluetoothPrinter.printBytes(
      address: device.address,
      data: bytes,        // ✅ Correct type
      keepConnected: false,
    );



      // ✅ Mark order as printed
      await api.markAsPrinted(order.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printed successfully')),
      );
    } catch (e) {
      debugPrint('PrinterService error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }
}
