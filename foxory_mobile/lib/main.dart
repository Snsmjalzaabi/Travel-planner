import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'app.dart';
import 'core/database_helper.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Ensure sample data is seeded on first launch
  final db = await openDatabase(
    join(await getDatabasesPath(), 'foxory.db'),
    version: 1,
  );
  await db.close();

  runApp(FoxoryApp(prefs: prefs, dbHelper: DatabaseHelper()));
}
