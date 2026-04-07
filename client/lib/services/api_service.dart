import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // ── SERVER URL ────────────────────────────────────────────
  // Chrome / Windows / Linux use localhost
  // Android (emulator) uses 10.0.2.2 to reach host machine
  // Android (physical USB) uses your PC's local IP
  //
  // CHANGE THIS IP to your PC's local IP for USB Android:
  static const String _pcLocalIP = '192.168.1.100';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5000/api';
    if (Platform.isAndroid) {
      // Emulator uses 10.0.2.2, physical device needs PC IP
      return 'http://10.0.2.2:5000/api';
      // For physical USB Android device, comment above and use:
      // return 'http://$_pcLocalIP:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  // Same logic for socket server URL
  static String get socketUrl {
    if (kIsWeb) return 'http://localhost:5000';
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
      // For physical USB Android device:
      // return 'http://$_pcLocalIP:5000';
    }
    return 'http://localhost:5000';
  }

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // ── Token helpers ─────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Headers ───────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  // ── SIGNUP ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'full_name': fullName,
        'email': email,
        'password': password,
      }),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── LOGIN ─────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── LOGOUT ────────────────────────────────────────────────
  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$baseUrl/auth/logout'), headers: headers);
    await deleteToken();
  }

  // ── GET ME ────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/auth/me'), headers: headers);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── LOOKUP DEVICE ─────────────────────────────────────────
  static Future<Map<String, dynamic>> lookupDevice(String code) async {
    final headers = await _authHeaders();
    final clean = code.replaceAll('-', '');
    final res = await http.get(
      Uri.parse('$baseUrl/device/lookup/$clean'),
      headers: headers,
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
