class OrderModel {
  final int id;
  final String customerName;
  final String? waiterName;
  final double grandTotal;
  final bool isPrinted;
  final String referenceCode;
  final String counterNumber;
  final String tableNumber;
  final String date;
    DateTime get dateTime => DateTime.parse(date).toLocal(); // 👈 automatically local

  final List<OrderItem> items;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.waiterName,
    required this.grandTotal,
    required this.isPrinted,
    required this.referenceCode,
    required this.date,
    required this.items,
    required this.counterNumber,
    required this.tableNumber,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      customerName: json['customer']?['name'] ?? "Unknown",
      waiterName: json['waiter']?['name'],
      grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0.0,
      isPrinted: (json['is_printed'] == 1) || (json['is_printed'] == true),
      referenceCode: json['reference_code'] ?? json['reference'] ?? '#${json['id'] ?? 0}',
      date: json['created_at'] ?? json['date'] ?? '',
      items: (json['sale_items'] as List? ?? []).map((i) => OrderItem.fromJson(i)).toList(),
      counterNumber: json['counter_number'] ?? '',
      tableNumber:  json['table_number'] ?? '',
    );
  }
}

class OrderItem {
  final String productName;
  final int quantity;
  final double subtotal;

  OrderItem({
    required this.productName,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product']?['name'] ?? json['name'] ?? 'Product',
      quantity: (json['quantity'] ?? 0) as int,
      subtotal: (json['sub_total'] as num?)?.toDouble() ?? (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
