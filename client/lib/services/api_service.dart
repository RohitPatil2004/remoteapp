import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // ── Change this to your server IP/URL when deploying ─────────────────────────
  static const String baseUrl = 'http://localhost:5000/api';

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  // ── Token helpers ─────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Headers ───────────────────────────────────────────────────────────────────
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

  // ── SIGNUP ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: _jsonHeaders,
      body: jsonEncode(
          {'full_name': fullName, 'email': email, 'password': password}),
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────────
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

  // ── LOGOUT ────────────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$baseUrl/auth/logout'), headers: headers);
    await deleteToken();
  }

  // ── GET ME ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getMe() async {
    final headers = await _authHeaders();
    final res = await http.get(Uri.parse('$baseUrl/auth/me'), headers: headers);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── LOOKUP DEVICE ─────────────────────────────────────────────────────────────
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
