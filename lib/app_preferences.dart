import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionState {
  final int currentPage;
  final bool codeAccepted;
  final bool cameraGranted;
  final bool faceScanned;
  final bool verified;

  const SessionState({
    required this.currentPage,
    required this.codeAccepted,
    required this.cameraGranted,
    required this.faceScanned,
    required this.verified,
  });
}

class AppPreferences {
  static const _themeModeKey = 'theme_mode';
  static const _currentPageKey = 'current_page';
  static const _codeAcceptedKey = 'code_accepted';
  static const _cameraGrantedKey = 'camera_granted';
  static const _faceScannedKey = 'face_scanned';
  static const _verifiedKey = 'verified';

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  static ThemeMode themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Future<ThemeMode> loadThemeMode() async {
    final prefs = await _prefs();
    return themeModeFromString(prefs.getString(_themeModeKey));
  }

  static Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _prefs();
    await prefs.setString(_themeModeKey, themeModeToString(mode));
  }

  static Future<SessionState> loadSessionState() async {
    final prefs = await _prefs();
    return SessionState(
      currentPage: prefs.getInt(_currentPageKey) ?? 0,
      codeAccepted: prefs.getBool(_codeAcceptedKey) ?? false,
      cameraGranted: prefs.getBool(_cameraGrantedKey) ?? false,
      faceScanned: prefs.getBool(_faceScannedKey) ?? false,
      verified: prefs.getBool(_verifiedKey) ?? false,
    );
  }

  static Future<void> saveSessionState({
    required int currentPage,
    required bool codeAccepted,
    required bool cameraGranted,
    required bool faceScanned,
    required bool verified,
  }) async {
    final prefs = await _prefs();
    await prefs.setInt(_currentPageKey, currentPage);
    await prefs.setBool(_codeAcceptedKey, codeAccepted);
    await prefs.setBool(_cameraGrantedKey, cameraGranted);
    await prefs.setBool(_faceScannedKey, faceScanned);
    await prefs.setBool(_verifiedKey, verified);
  }
}
