// lib/pages/store_selection_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'sales_dashboard.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({Key? key}) : super(key: key);
  @override State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  late Future<List<dynamic>> _storesFuture;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStores();
  }

  Future<List<dynamic>> _fetchStores() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/admin/stores'),
      headers: await ApiService().getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['stores'] ?? [];
    } else if (response.statusCode == 401) {
      ApiService().logout();
      Navigator.of(context).pushReplacementNamed('/');
      return [];
    } else {
      throw Exception('Failed to load stores');
    }
  }

  Future<void> _selectStore(Map<String, dynamic> store) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/admin/select-store'),
        headers: await ApiService().getHeaders(),
        body: jsonEncode({'store_id': store['id']}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await ApiService().saveCurrentStore(
          data['current_store_id'],
          data['current_tenant_id'],
          store['name'],
        );

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SalesDashboard()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to select store')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Icon(Icons.storefront, size: 100, color: Colors.white),
              const SizedBox(height: 24),
              const Text('Select Store', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              const Text('Choose the store you want to manage', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 40),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _storesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    }
                    final stores = snapshot.data!;
                    if (stores.isEmpty) {
                      return const Center(child: Text('No stores found', style: TextStyle(color: Colors.white70)));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: stores.length,
                      itemBuilder: (ctx, i) {
                        final store = stores[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(store['name'][0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            title: Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(store['address'] ?? 'No address'),
                            trailing: const Icon(Icons.arrow_forward_ios),
                            onTap: () => _selectStore(store),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}