import 'package:flutter/material.dart';
import '../widgets/orders_tab.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Tab> tabs = const [
    Tab(text: "All Orders"),
    Tab(text: "New"),
    Tab(text: "Printed"),
    Tab(text: "POS"),
    Tab(text: "Waiter"),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabView(String type) => OrdersTab(type: type);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Dashboard"),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.green,
          unselectedLabelColor: Colors.white,
          indicatorColor: Colors.yellow,
          indicatorWeight: 3,
          tabs: tabs,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabView('all'),
          _buildTabView('new'),
          _buildTabView('printed'),
          _buildTabView('pos'),
          _buildTabView('waiter'),
        ],
      ),
    );
  }
}
