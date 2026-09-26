import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class AppSettings {
  bool _darkMode = false;
  bool _useSystemTheme = true;
  bool _notificationsEnabled = true;
  bool _syncOnWifiOnly = true;
  String _homeWifiSsid = '';
  String _piAddress = '';
  int _piPort = 3000;
  String _deviceId = '';
  String _syncPassword = '';
  DateTime? _lastSync;
  List<String> _syncEnabledModules = ['trips', 'notes', 'tasks', 'expenses', 'photos', 'files'];

  // Getters
  bool get darkMode => _darkMode;
  bool get useSystemTheme => _useSystemTheme;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get syncOnWifiOnly => _syncOnWifiOnly;
  String get homeWifiSsid => _homeWifiSsid;
  String get piAddress => _piAddress;
  int get piPort => _piPort;
  String get deviceId => _deviceId;
  String get syncPassword => _syncPassword;
  DateTime? get lastSync => _lastSync;
  List<String> get syncEnabledModules => _syncEnabledModules;

  // Setters
  set darkMode(bool value) => _darkMode = value;
  set useSystemTheme(bool value) => _useSystemTheme = value;
  set notificationsEnabled(bool value) => _notificationsEnabled = value;
  set syncOnWifiOnly(bool value) => _syncOnWifiOnly = value;
  set homeWifiSsid(String value) => _homeWifiSsid = value;
  set piAddress(String value) => _piAddress = value;
  set piPort(int value) => _piPort = value;
  set deviceId(String value) => _deviceId = value;
  set syncPassword(String value) => _syncPassword = value;
  set lastSync(DateTime? value) => _lastSync = value;
  set syncEnabledModules(List<String> value) => _syncEnabledModules = value;

  Future<void> load(SharedPreferences prefs) async {
    _darkMode = prefs.getBool('dark_mode') ?? false;
    _useSystemTheme = prefs.getBool('use_system_theme') ?? true;
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    _syncOnWifiOnly = prefs.getBool('sync_wifi_only') ?? true;
    _homeWifiSsid = prefs.getString('home_wifi_ssid') ?? '';
    _piAddress = prefs.getString('pi_address') ?? '';
    _piPort = prefs.getInt('pi_port') ?? 3000;
    _deviceId = prefs.getString('device_id') ?? '';
    _syncPassword = prefs.getString('sync_password') ?? '';
    final lastSyncStr = prefs.getString('last_sync');
    if (lastSyncStr != null) {
      _lastSync = DateTime.tryParse(lastSyncStr);
    }
    final modulesStr = prefs.getString('sync_modules');
    if (modulesStr != null) {
      _syncEnabledModules = modulesStr.split(',').where((s) => s.isNotEmpty).toList();
    }

    // Generate device ID if not set
    if (_deviceId.isEmpty) {
      _deviceId = DateTime.now().millisecondsSinceEpoch.toString() + '_' +
          (await _generateRandomString(8));
      await prefs.setString('device_id', _deviceId);
    }
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setBool('dark_mode', _darkMode);
    await prefs.setBool('use_system_theme', _useSystemTheme);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sync_wifi_only', _syncOnWifiOnly);
    await prefs.setString('home_wifi_ssid', _homeWifiSsid);
    await prefs.setString('pi_address', _piAddress);
    await prefs.setInt('pi_port', _piPort);
    await prefs.setString('device_id', _deviceId);
    await prefs.setString('sync_password', _syncPassword);
    if (_lastSync != null) {
      await prefs.setString('last_sync', _lastSync!.toIso8601String());
    }
    await prefs.setString('sync_modules', _syncEnabledModules.join(','));
  }

  Future<String> _generateRandomString(int length) async {
    final chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (i) => chars[random % chars.length]).join();
  }

  ThemeMode get themeMode {
    if (_useSystemTheme) return ThemeMode.system;
    return _darkMode ? ThemeMode.dark : ThemeMode.light;
  }
}
