import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'app.dart';
import 'core/database_helper.dart';
import 'core/theme.dart';
import 'core/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize app settings
  final settings = AppSettings();

  // Initialize database
  final dbHelper = DatabaseHelper();
  await dbHelper.init();

  // Load app preferences
  final prefs = await SharedPreferences.getInstance();
  await settings.load(prefs);

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(FoxoryApp(settings: settings, dbHelper: dbHelper));
}
