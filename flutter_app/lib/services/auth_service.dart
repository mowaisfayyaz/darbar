import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class AuthService extends ChangeNotifier {
  static const String _baseUrl = 'http://10.0.2.2:8000/api';
  final Dio _dio = Dio();

  String? _userId;
  String? _userName;
  String? _userRole;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get userRole => _userRole;
  bool get isLoggedIn => _userId != null;
  bool get isProvider => _userRole == 'provider';

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _userRole = prefs.getString('user_role');
    notifyListeners();
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? category,
    String? city,
    String? area,
  }) async {
    final response = await _dio.post('$_baseUrl/auth/register/', data: {
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
      if (category != null) 'category': category,
      if (city != null) 'city': city,
      if (area != null) 'area': area,
    });
    await _saveSession(response.data);
    return response.data;
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String role,
  }) async {
    final response = await _dio.post('$_baseUrl/auth/login/', data: {
      'phone': phone,
      'role': role,
    });
    await _saveSession(response.data);
    return response.data;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = data['id'];
    _userName = data['name'];
    _userRole = data['role'];
    await prefs.setString('user_id', _userId!);
    await prefs.setString('user_name', _userName!);
    await prefs.setString('user_role', _userRole!);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _userId = null;
    _userName = null;
    _userRole = null;
    notifyListeners();
  }
}
