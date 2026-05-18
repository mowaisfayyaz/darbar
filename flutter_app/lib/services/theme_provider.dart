import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppStateProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  int _avatarIndex = 0;
  Uint8List? _customAvatarBytes;

  bool get isDarkMode => _isDarkMode;
  int get avatarIndex => _avatarIndex;
  Uint8List? get customAvatarBytes => _customAvatarBytes;

  // The 6 icon-type avatars from previously
  final List<IconData> avatarIcons = [
    Icons.face,
    Icons.face_retouching_natural,
    Icons.support_agent,
    Icons.engineering,
    Icons.construction,
    Icons.psychology,
  ];

  IconData get currentAvatarIcon => avatarIcons[_avatarIndex];

  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void changeAvatar(int index) {
    _avatarIndex = index;
    _customAvatarBytes = null; // Clear custom upload when selecting preset icon
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
