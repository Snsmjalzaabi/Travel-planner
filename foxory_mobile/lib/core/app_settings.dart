import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Singleton for app settings stored in SharedPreferences
class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  bool _darkMode = true;
  bool _useSystemTheme = false;
  SharedPreferences? _prefs;
  String piAddress = '10.10.10.10';
  int piPort = 8080;
  String deviceId = '';
  String syncPassword = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _darkMode = _prefs!.getBool('dark_mode') ?? true;
    _useSystemTheme = _prefs!.getBool('use_system_theme') ?? false;
  }

  bool get darkMode => _darkMode;
  bool get useSystemTheme => _useSystemTheme;

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    await _prefs?.setBool('dark_mode', value);
  }

  Future<void> setUseSystemTheme(bool value) async {
    _useSystemTheme = value;
    await _prefs?.setBool('use_system_theme', value);
  }
}
