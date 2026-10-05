import 'package:shared_preferences/shared_preferences.dart';

/// Singleton for app settings stored in SharedPreferences.
class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  bool _darkMode = true;
  bool _useSystemTheme = false;
  SharedPreferences? _prefs;

  // Pi sync defaults: personal/local use on Sultan's Pi.
  String piAddress = '100.82.155.42';
  int piPort = 9101;
  String deviceId = '';
  String syncPassword = '';
  String lastSyncAt = '';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _darkMode = _prefs!.getBool('dark_mode') ?? true;
    _useSystemTheme = _prefs!.getBool('use_system_theme') ?? false;
    piAddress = _prefs!.getString('pi_address') ?? piAddress;
    piPort = _prefs!.getInt('pi_port') ?? piPort;
    deviceId = _prefs!.getString('device_id') ?? _defaultDeviceId();
    syncPassword = _prefs!.getString('sync_password') ?? '';
    lastSyncAt = _prefs!.getString('last_sync_at') ?? '';
    await _prefs!.setString('device_id', deviceId);
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

  Future<void> setPiAddress(String value) async {
    piAddress = value.trim();
    await _prefs?.setString('pi_address', piAddress);
  }

  Future<void> setPiPort(int value) async {
    piPort = value;
    await _prefs?.setInt('pi_port', value);
  }

  Future<void> setSyncPassword(String value) async {
    syncPassword = value;
    await _prefs?.setString('sync_password', value);
  }

  Future<void> setLastSyncAt(DateTime value) async {
    lastSyncAt = value.toIso8601String();
    await _prefs?.setString('last_sync_at', lastSyncAt);
  }

  String _defaultDeviceId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'foxory-phone-$now';
  }
}
