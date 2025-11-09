import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'api_service.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  final ApiService api = ApiService();
  static const _prefsKeyPrinterAddress = 'printer_address';

  /// Print order using ESC/POS bytes (simplest & works on most printers)
  Future<void> printOrder(BuildContext? context, OrderModel order) async {
    try {
      // ✅ Permissions
      await PermissionHelper.requestBluetoothPermissions();

      // ✅ Try saved printer first
      final prefs = await SharedPreferences.getInstance();
      String? address = prefs.getString(_prefsKeyPrinterAddress);

      // If no saved address, select device via UI
      if (address == null) {
        if (context == null) throw Exception('No saved printer and no UI context available to select a printer.');
        final device = await FlutterBluetoothPrinter.selectDevice(context);
        if (device == null) return;
        address = device.address;
        await prefs.setString(_prefsKeyPrinterAddress, address);
      }

      final DateFormat df = DateFormat('yyyy-MM-dd HH:mm');

      // ✅ Build receipt text
      final Uint8List bytes = _buildReceipt(order, df);

      try {
        await FlutterBluetoothPrinter.printBytes(
          address: address,
          data: bytes,
          keepConnected: false,
        );
      } catch (e) {
        // If failed (e.g. printer not available), try selecting a new device
        if (context == null) rethrow;
        final device = await FlutterBluetoothPrinter.selectDevice(context);
        if (device == null) rethrow;
        await prefs.setString(_prefsKeyPrinterAddress, device.address);
        await FlutterBluetoothPrinter.printBytes(
          address: device.address,
          data: bytes,
          keepConnected: false,
        );
      }



      // ✅ Mark order as printed
      await api.markAsPrinted(order.id);

      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Printed successfully')),
        );
      }
    } catch (e) {
      debugPrint('PrinterService error: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  /// Headless print without requiring BuildContext (no UI, uses saved printer or fails)
  Future<void> printOrderHeadless(OrderModel order) async {
    await printOrder(null, order);
  }

  Uint8List _buildReceipt(OrderModel order, DateFormat df) {
    final List<String> lines = [];
    final String printedDate = order.date.isNotEmpty ? order.date : df.format(DateTime.now());

    // Header
    lines.add('COUNTER: ${order.counterNumber}');
    lines.add('DATE   : $printedDate');
    lines.add('--------------------------------');
    lines.add('Order: #${order.id}');
    if (order.customerName.isNotEmpty) {
      lines.add('Customer: ${order.customerName}');
    }
    lines.add('Waiter: ${order.waiterName ?? "-"}');
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
    lines.add('TOTAL:'.padRight(20) + order.grandTotal.toStringAsFixed(2).padLeft(11));
    lines.add('\nThank you!\n\n');

    return Uint8List.fromList(lines.join('\n').codeUnits);
  }
}
