// lib/widgets/orders_tab.dart
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';
import '../widgets/order_card.dart';
import '../widgets/order_detail_modal.dart';

class OrdersTab extends StatefulWidget {
  final String type;
  const OrdersTab({super.key, required this.type});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<OrderModel> _orders = [];
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadOrders(page: 1);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.95 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _orders.clear();
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      final newOrders = await _api.getOrdersByType(
        widget.type,
        page: page,
      );
      setState(() {
        if (page == 1) {
          _orders = newOrders;
        } else {
          _orders.addAll(newOrders);
        }
        _currentPage = page;
        _hasMore = newOrders.length == 10; // Adjust based on your per_page (default Laravel = 15 or 20)
        _isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading orders: $e')),
        );
      }
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadOrders(page: _currentPage + 1);
  }

  Future<void> _refresh() async {
    await _loadOrders(page: 1);
  }

  void _showOrderDetailsDialog(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderDetailModal(
        order: order,
        onPrinted: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_orders.isEmpty && _currentPage == 1 && !_isLoadingMore) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("No orders available"),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 94, 8, 8), // 👈 Added top padding
        // padding: const EdgeInsets.all(8),
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator at bottom
          if (index == _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final order = _orders[index];
          return OrderCard(
            order: order,
            onViewDetails: () => _showOrderDetailsDialog(order),
            onPrint: () {},
          );
        },
      ),
    );
  }
}