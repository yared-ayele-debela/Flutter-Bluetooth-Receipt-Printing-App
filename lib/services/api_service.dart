import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class ApiService {
  static int? _adminId;
  // Change baseUrl to your actual server IP (same subnet as device)
  static const String baseUrl = "https://eam.afroel.com/api"; // or http://192.168.1.14:8000/api

  static String? _token;
  static Map<String, dynamic>? _admin;

  static int? _currentStoreId;
  static String? _currentTenantId;
  static String? _currentStoreName;

  // Save token after login
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  // Save admin data (optional)
  Future<void> saveAdmin(Map<String, dynamic> admin) async {
    _admin = admin;
    _adminId = admin['id']; // ← Save admin ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_data', jsonEncode(admin));
  }

  Future<void> saveCurrentStore(int storeId, String tenantId, String storeName) async {
    _currentStoreId = storeId;
    _currentTenantId = tenantId;
    _currentStoreName = storeName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_store_id', storeId);
    await prefs.setString('current_tenant_id', tenantId);
    await prefs.setString('current_store_name', storeName);
  }

  Future<void> clearCurrentStore() async {
    _currentStoreId = null;
    _currentTenantId = null;
    _currentStoreName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_store_id');
    await prefs.remove('current_tenant_id');
    await prefs.remove('current_store_name');
  }

  static int? get adminId => _adminId;
  // Load token on app start
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    final adminJson = prefs.getString('admin_data');
    if (adminJson != null) {
      _admin = jsonDecode(adminJson);
      _adminId = _admin?['id'];
    }
    final id = prefs.getInt('current_store_id');
    final tenant = prefs.getString('current_tenant_id');
    final name = prefs.getString('current_store_name');
    if (id != null && tenant != null && name != null) {
      _currentStoreId = id;
      _currentTenantId = tenant;
      _currentStoreName = name;
    }
  }

  // Get current token
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  static int? get currentStoreId => _currentStoreId;
  static String? get currentTenantId => _currentTenantId;
  static String? get currentStoreName => _currentStoreName;

  // Add Authorization header automatically
  Future<Map<String, String>> getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _admin = null;
    _currentStoreId = null;
    _currentTenantId = null;
    _currentStoreName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear everything

    try {
      await http.post(Uri.parse('$baseUrl/admin/logout'), headers: await getHeaders());
    } catch (_) {}
  }


  Future<void> markAsPrinted(int orderId) async {
    final url = "$baseUrl/orders/$orderId/mark-printed";
    try {
      final resp = await http.post(Uri.parse(url));
      if (resp.statusCode != 200) {
        // optional: handle error
        print('Failed markAsPrinted: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('API error markAsPrinted: $e');
    }
  }
  /// Fetch orders with optional pagination
  /// [type] = 'all', 'new', 'printed', 'pos', 'waiter'
  /// [page] = page number for pagination (default: 1)
  Future<List<OrderModel>> getOrdersByType(
      String type, {
        int page = 1,
      }) async {
    // Build correct endpoint
    String endpoint = '/orders';
    if (type == 'new') endpoint = '/orders/new';
    else if (type == 'printed') endpoint = '/orders/printed';
    else if (type == 'pos') endpoint = '/orders/pos';
    else if (type == 'waiter') endpoint = '/orders/waiter';

    // Add pagination
    final uri = Uri.parse('$baseUrl$endpoint').replace(
      queryParameters: {'page': page.toString()},
    );

    try {
      final response = await http.get(
        uri,
        headers: await getHeaders(),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        List<dynamic> ordersJson = [];

        if (body is List) {
          ordersJson = body;
        } else if (body is Map<String, dynamic>) {
          // Laravel pagination format: { "data": [...], ... }
          if (body['data'] is List) {
            ordersJson = body['data'];
          }
          // Some APIs return { "orders": [...] }
          else if (body['orders'] is List) {
            ordersJson = body['orders'];
          }
        }

        if (ordersJson.isEmpty) {
          return [];
        }

        return ordersJson
            .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Handle "Store not selected" → redirect user
      else if (response.statusCode == 400) {
        final errorBody = jsonDecode(response.body);
        final msg = errorBody['message']?.toString() ?? 'Bad request';

        if (msg.toLowerCase().contains('store') ||
            msg.toLowerCase().contains('selected') ||
            msg.toLowerCase().contains('tenant')) {
          throw StoreNotSelectedException(msg);
        }
        throw Exception('Bad request: $msg');
      }

      // Token expired or invalid
      else if (response.statusCode == 401) {
        await logout();
        throw Exception("Session expired. Please login again.");
      }

      // Other errors
      else {
        throw Exception("Failed to load orders (${response.statusCode}: ${response.body})");
      }
    } on StoreNotSelectedException {
      rethrow; // Let dashboard handle redirect
    } catch (e) {
      // Network error, timeout, etc.
      throw Exception("Network error: $e");
    }
  }

  Future<OrderModel> getOrderById(int orderId) async {
    final url = "$baseUrl/orders/$orderId";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        if (body['data'] is Map<String, dynamic>) {
          return OrderModel.fromJson(body['data'] as Map<String, dynamic>);
        }
        return OrderModel.fromJson(body);
      } else {
        throw Exception("Unexpected response type: ${body.runtimeType}");
      }
    } else {
      throw Exception("Failed to load order ($orderId): ${response.statusCode}");
    }
  }

  // In services/api_service.dart
  Future<void> saveRememberMe(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', remember);
  }


}

class StoreNotSelectedException implements Exception {

  final String message;

  StoreNotSelectedException([this.message = 'Please select a store to continue.']);

  @override
  String toString() => 'StoreNotSelectedException: $message';

  /// Optional: Add a code for easier debugging
  String get code => 'STORE_NOT_SELECTED';

}
