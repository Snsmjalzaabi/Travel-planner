import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'app.dart';
import 'core/database_helper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Ensure sample data is seeded on first launch
  final db = await openDatabase(
    join(await getDatabasesPath(), 'foxory.db'),
    version: 1,
  );
  await db.close();

  final dbHelper = DatabaseHelper();

  // Wire up alerts: passport expiry, visa expiry
  final alerts = AlertService(dbHelper);
  await alerts.init();
  await alerts.ensureChannel();
  await alerts.requestPermission();
  await alerts.scheduleDailyCheck(hour: 8, minute: 0);

  runApp(FoxoryApp(prefs: prefs, dbHelper: dbHelper, alerts: alerts));
}
