import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';

class ApiService {
  // Change baseUrl to your actual server IP (same subnet as device)
  final String baseUrl = "http://192.168.1.14:8000/api/orders";

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
}
