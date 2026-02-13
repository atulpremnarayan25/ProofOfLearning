// ──────────────────────────────────────────────
// providers/auth_provider.dart — Authentication state
// ──────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;

  String? _token;
  String? _userId;
  String? _name;
  String? _email;
  String? _role;
  bool _isLoading = false;
  String? _error;

  AuthProvider(this._api);

  // Getters
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userId => _userId;
  String? get name => _name;
  String? get email => _email;
  String? get role => _role;
  String? get error => _error;
  bool get isTeacher => _role == 'teacher';
  bool get isStudent => _role == 'student';

  /// Try to restore token from SharedPreferences on app start.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedUserId = prefs.getString('userId');
    final savedName = prefs.getString('name');
    final savedEmail = prefs.getString('email');
    final savedRole = prefs.getString('role');

    if (savedToken != null) {
      _token = savedToken;
      _userId = savedUserId;
      _name = savedName;
      _email = savedEmail;
      _role = savedRole;
      _api.setToken(savedToken);
      notifyListeners();
    }
  }

  /// Register a new user.
  Future<bool> register(String name, String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.register(name, email, password, role);
      await _handleAuthResponse(res.data);
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log in with email and password.
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await _api.login(email, password);
      await _handleAuthResponse(res.data);
      return true;
    } catch (e) {
      _error = _extractError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Log out — clear token and state.
  Future<void> logout() async {
    _token = null;
    _userId = null;
    _name = null;
    _email = null;
    _role = null;
    _api.clearToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // ── Helpers ────────────────────────────────
  Future<void> _handleAuthResponse(Map<String, dynamic> data) async {
    _token = data['token'];
    final user = data['user'];
    _userId = user['id'];
    _name = user['name'];
    _email = user['email'];
    _role = user['role'];
    _isLoading = false;

    _api.setToken(_token!);

    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('userId', _userId!);
    await prefs.setString('name', _name!);
    await prefs.setString('email', _email!);
    await prefs.setString('role', _role!);

    notifyListeners();
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        // Dio error
        final dioErr = e as dynamic;
        if (dioErr.response?.data != null && dioErr.response.data['error'] != null) {
          return dioErr.response.data['error'];
        }
      } catch (_) {}
    }
    return 'Something went wrong. Please try again.';
  }
}
