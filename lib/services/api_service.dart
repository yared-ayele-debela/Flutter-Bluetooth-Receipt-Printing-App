import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class ApiService {
  // Change baseUrl to your actual server IP (same subnet as device)
  final String baseUrl = "https://eam.afroel.com/api/orders";

  static String? _token;
  static Map<String, dynamic>? _admin;

  // Save token after login
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_token', token);
  }

  // Save admin data (optional)
  Future<void> saveAdmin(Map<String, dynamic> admin) async {
    _admin = admin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_data', jsonEncode(admin));
  }

  // Load token on app start
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('api_token');
    final adminJson = prefs.getString('admin_data');
    if (adminJson != null) {
      _admin = jsonDecode(adminJson);
    }
  }

  // Get current token
  String? get token => _token;

  // Check if logged in
  bool get isLoggedIn => _token != null;

  // Add Authorization header automatically
  Future<Map<String, String>> getHeaders() async {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  // Logout
  Future<void> logout() async {
    _token = null;
    _admin = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    await prefs.remove('admin_data');

    // Call Laravel logout (optional, clears token on server)
    try {
      await http.post(Uri.parse('$baseUrl/admin/logout'), headers: await getHeaders());
    } catch (_) {}
  }


  Future<void> markAsPrinted(int orderId) async {
    final url = "$baseUrl/$orderId/mark-printed";
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

  Future<List<OrderModel>> getOrdersByType(String type) async {
    String url = baseUrl;
    if (type == "new") url = "$baseUrl/new";
    else if (type == "printed") url = "$baseUrl/printed";
    else if (type == "pos") url = "$baseUrl/pos";
    else if (type == "waiter") url = "$baseUrl/waiter";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is List) {
        return body.map<OrderModel>((json) => OrderModel.fromJson(json)).toList();
      } else if (body is Map) {
        // handle API pagination structure like { data: [...] }
        if (body['data'] is List) {
          return (body['data'] as List).map((j) => OrderModel.fromJson(j)).toList();
        }
        // no data
        return [];
      } else {
        throw Exception("Unexpected response type: ${body.runtimeType}");
      }
    } else {
      throw Exception("Failed to load orders (${response.statusCode})");
    }
  }

  Future<OrderModel> getOrderById(int orderId) async {
    final url = "$baseUrl/$orderId";
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
}
