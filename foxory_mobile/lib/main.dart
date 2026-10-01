import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/database_helper.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // DatabaseHelper owns the connection and creates the schema on first open.
  final dbHelper = DatabaseHelper();
  final alerts = AlertService(dbHelper);

  // Initialize notification plugin — quick, but guard with timeout
  // so a hung plugin init never blocks the splash.
  const timeout = Duration(seconds: 10);
  try {
    await Future.any([alerts.init(), Future.delayed(timeout)]);
  } catch (_) {
    // init timed out or failed — notifications won't work, but app launches
  }

  // Create notification channel (Android only, fast)
  try {
    await Future.any([alerts.ensureChannel(), Future.delayed(timeout)]);
  } catch (_) {}

  // Request notification permission with timeout.
  // On Android 13+ this may show a system dialog. If it doesn't
  // appear within the timeout, continue — user can grant from
  // Settings later and notifications will start working then.
  try {
    await Future.any([alerts.requestPermission(), Future.delayed(timeout)]);
  } catch (_) {}

  // Schedule daily check with timeout
  try {
    await Future.any([alerts.scheduleDailyCheck(hour: 8, minute: 0), Future.delayed(timeout)]);
  } catch (_) {}

  runApp(FoxoryApp(prefs: prefs, dbHelper: dbHelper, alerts: alerts));
}
