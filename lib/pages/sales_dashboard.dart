import 'package:flutter/material.dart';
import '../widgets/orders_tab.dart';
import '../services/api_service.dart';
import '../models/order_model.dart';
import '../services/printer_service.dart';
import 'package:flutter_bluetooth_printer/flutter_bluetooth_printer.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import 'login.dart';

class SalesDashboard extends StatefulWidget {
  const SalesDashboard({super.key});

  @override
  State<SalesDashboard> createState() => _SalesDashboardState();
}

class _SalesDashboardState extends State<SalesDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();
  final PrinterService _printer = PrinterService();

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

  // Refresh stats + printer status
  void _refreshAll() {
    setState(() {
      _statsFuture = _loadStats();
    });
  }

  // Show SnackBar at TOP
  void _showTopSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // Open full Bluetooth device list
  Future<void> _openBluetoothDeviceList(BuildContext context) async {
    try {
      final device = await FlutterBluetoothPrinter.selectDevice(context);
      if (device == null) return;

      await _printer.savePrinter(device.address, device.name ?? 'Printer');
      _refreshAll();

      _showTopSnackBar('Connected: ${device.name ?? 'Printer'}');
    } catch (e) {
      _showTopSnackBar('Failed to connect printer', isError: true);
    }
  }

  // Long-press → Disconnect printer
  Future<void> _onBluetoothLongPress(BuildContext context) async {
    final name = await _printer.getSavedPrinterName() ?? 'Printer';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Printer?'),
        content: Text('Remove saved printer: $name'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await PrinterService.clearSavedPrinter();
      _refreshAll();
      _showTopSnackBar('Printer disconnected');
    }
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
      final d = o.dateTime;
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
                    // Refresh
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshAll,
                    ),


                    // Bluetooth Icon + Tooltip + Long-press Disconnect
                    FutureBuilder<Map<String, String?>>(
                      future: Future.wait([
                        _printer.getSavedPrinterAddress(),
                        _printer.getSavedPrinterName(),
                      ]).then((list) => {
                            'address': list[0],
                            'name': list[1],
                          }),
                      builder: (context, snap) {
                        final address = snap.data?['address'];
                        final name = snap.data?['name'];
                        final isConnected = address?.isNotEmpty == true;

                        return IconButton(
                          icon: Icon(
                            Icons.bluetooth,
                            color: isConnected ? Colors.green : Colors.white70,
                          ),
                          tooltip: isConnected
                              ? 'Connected: $name'
                              : 'Connect Bluetooth printer',
                          onPressed: () => _openBluetoothDeviceList(context),
                          onLongPress: isConnected
                              ? () => _onBluetoothLongPress(context)
                              : null,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      tooltip: 'Logout',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                  SizedBox(width: 12),
                                  Text('Confirm Logout'),
                                ],
                              ),
                              content: const Text('Are you sure you want to log out?\nYou will need to login again to continue.'),
                              actions: [
                                // Cancel Button
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  child: const Text('Cancel'),
                                ),
                                // Confirm Logout Button
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
                                  onPressed: () async {
                                    Navigator.of(context).pop(); // Close the dialog first

                                    // Optional: show a quick snackbar
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Logging out...'), duration: Duration(seconds: 1)),
                                    );
                                    // Clear token locally + call backend logout
                                    await ApiService().logout();
                                    // Go back to login screen (user can't press back to return)
                                    if (!context.mounted) return; // Safety check (Flutter 3.7+)

                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const LoginPage()),
                                    );
                                  },
                                  child: const Text('Yes, Logout', style: TextStyle(color: Colors.white)),
                                )
                              ],
                            );
                          },
                        );
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
                      child: SafeArea(
                        top: true,
                        bottom: false,
                        child: _StatsHeader(snapshot: snapshot),
                      ),
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(48),
                    child: Container(
                      color: Colors.indigo,
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

// ======================
// _DashboardStats & _StatsHeader (unchanged)
// ======================

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