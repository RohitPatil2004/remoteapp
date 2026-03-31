import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;

  String get deviceCode => _user?['device_code_display'] ?? '----  ----  ----';
  String get fullName => _user?['full_name'] ?? '';
  String get email => _user?['email'] ?? '';

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Auto-login from stored token ──────────────────────────────────────────────
  Future<bool> tryAutoLogin() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!loggedIn) return false;
    try {
      final res = await ApiService.getMe();
      if (res['success'] == true) {
        _user = res['data'];
        notifyListeners();
        return true;
      }
    } catch (_) {}
    await ApiService.deleteToken();
    return false;
  }

  // ── SIGNUP ────────────────────────────────────────────────────────────────────
  Future<bool> signup(String fullName, String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.signup(
        fullName: fullName,
        email: email,
        password: password,
      );
      if (res['success'] == true) {
        final data = res['data'];
        await ApiService.saveToken(data['token']);
        _user = data['user'];
        _setLoading(false);
        return true;
      } else {
        _setError(res['message'] ?? 'Signup failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Connection error. Is the server running?');
      _setLoading(false);
      return false;
    }
  }

  // ── LOGIN ─────────────────────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final res = await ApiService.login(email: email, password: password);
      if (res['success'] == true) {
        final data = res['data'];
        await ApiService.saveToken(data['token']);
        _user = data['user'];
        _setLoading(false);
        return true;
      } else {
        _setError(res['message'] ?? 'Login failed');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Connection error. Is the server running?');
      _setLoading(false);
      return false;
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await ApiService.logout();
    _user = null;
    notifyListeners();
  }
}
