import 'package:flutter/material.dart';
import '../widgets/orders_tab.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  late Future<_DashboardStats> _statsFuture;

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
    _statsFuture = _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildTabView(String type) => OrdersTab(type: type);

  Future<_DashboardStats> _loadStats() async {
    final results = await Future.wait<List<OrderModel>>([
      _api.getOrdersByType('all'),
      _api.getOrdersByType('new'),
      _api.getOrdersByType('printed'),
      _api.getOrdersByType('pos'),
      _api.getOrdersByType('waiter'),
    ]);

    final all = results[0];
    final newly = results[1];
    final printed = results[2];
    final pos = results[3];
    final waiter = results[4];

    final totalSales = all.fold<double>(0, (p, e) => p + e.grandTotal);
    final today = DateTime.now();
    final todaySales = all.where((o) {
      final d = DateTime.tryParse(o.date);
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).fold<double>(0, (p, e) => p + e.grandTotal);

    return _DashboardStats(
      totalOrders: all.length,
      totalSales: totalSales,
      todaySales: todaySales,
      newCount: newly.length,
      printedCount: printed.length,
      posCount: pos.length,
      waiterCount: waiter.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DefaultTabController(
        length: tabs.length,
        child: FutureBuilder<_DashboardStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            return NestedScrollView(
              headerSliverBuilder: (context, innerScrolled) => [
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  expandedHeight: 520,
                  centerTitle: true,
                  title: const Text('Sales Dashboard'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {
                          _statsFuture = _loadStats();
                        });
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF22C55E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 64, 16, 12),
                      child: SafeArea(top: true, bottom: false, child: _StatsHeader(snapshot: snapshot)),
                    ),
                  ),
                  bottom: PreferredSize(
  preferredSize: const Size.fromHeight(48),
  child: Container(
    color: Colors.indigo, // 👈 your desired tab background color
    child: TabBar(
      controller: _tabController,
      isScrollable: true,
      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: Colors.white, width: 3),
        insets: EdgeInsets.symmetric(horizontal: 24),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      tabs: tabs,
    ),
  ),
),

                ),
              ],
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
          },
        ),
      ),
    );
  }
}

class _DashboardStats {
  final int totalOrders;
  final double totalSales;
  final double todaySales;
  final int newCount;
  final int printedCount;
  final int posCount;
  final int waiterCount;

  _DashboardStats({
    required this.totalOrders,
    required this.totalSales,
    required this.todaySales,
    required this.newCount,
    required this.printedCount,
    required this.posCount,
    required this.waiterCount,
  });
}

class _StatsHeader extends StatelessWidget {
  final AsyncSnapshot<_DashboardStats> snapshot;
  const _StatsHeader({required this.snapshot});

  String _formatCurrency(num v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Failed to load stats', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    final s = snapshot.data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.assessment, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Overview',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpiCard(context, title: 'Total Sales', value: '${_formatCurrency(s.totalSales)} ETB', icon: Icons.paid),
            _kpiCard(context, title: 'Today', value: '${_formatCurrency(s.todaySales)} ETB', icon: Icons.today),
            _kpiCard(context, title: 'Orders', value: '${s.totalOrders}', icon: Icons.shopping_bag),
            _kpiCard(context, title: 'New', value: '${s.newCount}', icon: Icons.fiber_new),
            _kpiCard(context, title: 'Printed', value: '${s.printedCount}', icon: Icons.print),
            _kpiCard(context, title: 'POS', value: '${s.posCount}', icon: Icons.point_of_sale),
            _kpiCard(context, title: 'Waiter', value: '${s.waiterCount}', icon: Icons.person_outline),
          ],
        ),
      ],
    );
  }

  Widget _kpiCard(BuildContext context, {required String title, required String value, required IconData icon}) {
    return Container(
      width: MediaQuery.of(context).size.width / 2 - 22,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
