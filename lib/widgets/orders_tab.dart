import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/order_card.dart';
import '../widgets/order_detail_modal.dart';

class OrdersTab extends StatefulWidget {
  final String type;
  const OrdersTab({super.key, required this.type});

  @override
  _OrdersTabState createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final ApiService apiService = ApiService();
  late Future<List<OrderModel>> ordersFuture;

  @override
  void initState() {
    super.initState();
    ordersFuture = apiService.getOrdersByType(widget.type);
  }

  Future<void> refresh() async {
    setState(() {
      ordersFuture = apiService.getOrdersByType(widget.type);
    });
  }

  void _showOrderDetailsDialog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return OrderDetailModal(
          order: order,
          onPrinted: () async {
            await refresh();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<OrderModel>>(
      future: ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("No orders available"),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        final orderList = snapshot.data!;
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.builder(
            itemCount: orderList.length,
            itemBuilder: (context, index) {
              final order = orderList[index];
              return OrderCard(
                order: order,
                onViewDetails: () => _showOrderDetailsDialog(order),
                onPrint: () {
                  // optional quick print action (we recommend using details modal)
                },
              );
            },
          ),
        );
      },
    );
  }
}
