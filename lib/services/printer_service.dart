import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'api_service.dart';
import '../models/order_model.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows a floating toast at the TOP of the screen
void showTopToast(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
class PrinterService {
  final ApiService api = ApiService();
  static const _kPrinterAddressKey = 'printer_address';
  static const _kPrinterNameKey = 'printer_name';

  Future<void> savePrinter(String address, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterAddressKey, address);
    await prefs.setString(_kPrinterNameKey, name);
  }

  Future<String?> getSavedPrinterAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterAddressKey);
  }

  Future<String?> getSavedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterNameKey);
  }

  Future<dynamic> selectAndSavePrinter(BuildContext context) async {
    final device = await FlutterBluetoothPrinter.selectDevice(context);
    if (device != null) {
      await savePrinter(device.address, device.name ?? 'Printer');
    }
    return device;
  }

  Uint8List _buildReceiptBytes(OrderModel order) {
  final DateFormat df = DateFormat('yyyy-MM-dd HH:mm');
  final List<String> lines = [];

  DateTime parsedDate;
  try {
    parsedDate = DateTime.parse(order.date);
  } catch (_) {
    parsedDate = DateTime.now();
  }
  final formattedDate = DateFormat('yyyy-MM-dd').format(parsedDate);
  final formattedTime = DateFormat('hh:mm a').format(parsedDate);


  // 🟩 Add top blank space (3 empty lines)
  lines.add('\n\n\n');
  // Header
  lines.add('        COUNTER: ${order.counterNumber}');
  lines.add('Date: $formattedDate     Time: $formattedTime');
  lines.add('--------------------------------');
  lines.add('Ref: ${order.referenceCode}');
  // lines.add('Order: #${order.id}');
  lines.add('Customer: ${order.customerName}');
  // lines.add('Waiter: ${order.waiterName ?? "-"}');
  lines.add('Waiter Name: ${order.waiterName ?? "-"}');
  lines.add('Table No.: ${order.tableNumber}     Order No.: ${order.id}');
  lines.add('--------------------------------');
  lines.add('Item                 QTY   Total');
  lines.add('--------------------------------');

  // Items
  for (var it in order.items) {
    final name = it.productName.length > 18
        ? it.productName.substring(0, 18)
        : it.productName;
    final qty = it.quantity.toString();
    final total = it.subtotal.toStringAsFixed(2);
    lines.add(name.padRight(18) + qty.padLeft(4) + total.padLeft(9));
  }

  // Footer
  lines.add('--------------------------------');
  lines.add('Grand Total:'.padRight(20) +
      order.grandTotal.toStringAsFixed(2).padLeft(11));
  lines.add('\nThank you for your purchase!');

  // 🟦 Add bottom blank space (5 empty lines)
  lines.add('\n\n\n\n\n');

  return Uint8List.fromList(lines.join('\n').codeUnits);
}


  Future<void> printOrderSmart(BuildContext context, OrderModel order) async {
    try {
      await PermissionHelper.requestBluetoothPermissions();
      final bytes = _buildReceiptBytes(order);
      String? address = await getSavedPrinterAddress();

      if (address == null || address.isEmpty) {
        final device = await selectAndSavePrinter(context);
        if (device == null) return;
        address = device.address;
      }

      final String targetAddress = address!;
      await FlutterBluetoothPrinter.printBytes(
        address: targetAddress,
        data: bytes,
        keepConnected: false,
      );

      await api.markAsPrinted(order.id);
     showTopToast(context, 'Printed successfully');
    } catch (e) {
      debugPrint('PrinterService smart print error: $e');
      try {
        final device = await selectAndSavePrinter(context);
        if (device == null) return;
        await FlutterBluetoothPrinter.printBytes(
          address: device.address,
          data: _buildReceiptBytes(order),
          keepConnected: false,
        );
        await api.markAsPrinted(order.id);
       showTopToast(context, 'Printed successfully');
      } catch (e2) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e2')));
      }
    }
  }

  Future<void> printOrderByIdSmart(BuildContext context, int orderId) async {
    final order = await api.getOrderById(orderId);
    await printOrderSmart(context, order);
  }

  Future<void> printOrder(BuildContext context, OrderModel order) async {
    try {
      await PermissionHelper.requestBluetoothPermissions();
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) return;
      await FlutterBluetoothPrinter.printBytes(
        address: device.address,
        data: _buildReceiptBytes(order),
        keepConnected: false,
      );
      await api.markAsPrinted(order.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printed successfully')));
    } catch (e) {
      debugPrint('PrinterService error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print failed: $e')));
    }
  }

  static Future<void> clearSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrinterAddressKey);
    await prefs.remove(_kPrinterNameKey);
  }
  
  // Add inside PrinterService class
Future<bool> autoPrintOrderById(int orderId) async {
  try {
    final order = await api.getOrderById(orderId);
    final address = await getSavedPrinterAddress();

    if (address == null || address.isEmpty) {
      debugPrint('No saved printer for auto-print');
      return false;
    }

    await PermissionHelper.requestBluetoothPermissions();
    final bytes = _buildReceiptBytes(order);

    await FlutterBluetoothPrinter.printBytes(
      address: address,
      data: bytes,
      keepConnected: false,
    );

    await api.markAsPrinted(order.id);
    debugPrint('Auto-printed order #$orderId');
    return true;
  } catch (e) {
    debugPrint('Auto-print failed: $e');
    return false;
  }
}
}


