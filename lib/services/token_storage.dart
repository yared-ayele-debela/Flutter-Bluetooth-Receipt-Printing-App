import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const storage = FlutterSecureStorage();
  static const key = "admin_token";

  static Future<void> saveToken(String token) async {
    await storage.write(key: key, value: token);
  }

  static Future<String?> getToken() async {
    return await storage.read(key: key);
  }

  static Future<void> deleteToken() async {
    await storage.delete(key: key);
  }
}
