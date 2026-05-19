import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  int _avatarIndex = 0;
  Uint8List? _customAvatarBytes;

  bool get isDarkMode => _isDarkMode;
  int get avatarIndex => _avatarIndex;
  Uint8List? get customAvatarBytes => _customAvatarBytes;

  // Session data
  String? _userId;
  String? _userName;
  String? _userEmail;
  String? _userRole;

  String? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole;
  bool get isLoggedIn => _userId != null;
  bool get isProvider => _userRole == 'provider';

  // The 6 icon-type avatars
  final List<IconData> avatarIcons = [
    Icons.face,
    Icons.face_retouching_natural,
    Icons.support_agent,
    Icons.engineering,
    Icons.construction,
    Icons.psychology,
  ];

  IconData get currentAvatarIcon => avatarIcons[_avatarIndex];

  /// Load saved preferences and session on startup
  Future<void> loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('dark_mode') ?? false;
    _avatarIndex = prefs.getInt('avatar_index') ?? 0;
    _userId = prefs.getString('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');
    _userRole = prefs.getString('user_role');
    notifyListeners();
  }

  /// Save session after login/register
  Future<void> saveSession({
    required String userId,
    required String userName,
    String? userEmail,
    required String userRole,
  }) async {
    _userId = userId;
    _userName = userName;
    _userEmail = userEmail;
    _userRole = userRole;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_name', userName);
    if (userEmail != null) await prefs.setString('user_email', userEmail);
    await prefs.setString('user_role', userRole);
    notifyListeners();
  }

  /// Clear session on logout
  Future<void> clearSession() async {
    _userId = null;
    _userName = null;
    _userEmail = null;
    _userRole = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    notifyListeners();
  }

  void toggleTheme(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    notifyListeners();
  }

  void changeAvatar(int index) async {
    _avatarIndex = index;
    _customAvatarBytes = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('avatar_index', index);
    notifyListeners();
  }

  void setCustomAvatarBytes(Uint8List bytes) {
    _customAvatarBytes = bytes;
    notifyListeners();
  }

  void clearCustomAvatar() {
    _customAvatarBytes = null;
    notifyListeners();
  }
}
