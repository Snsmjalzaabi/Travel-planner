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

  // Everything below is best-effort and must never block the first frame.
  // Each step is capped so a hung plugin cannot strand the app on splash.
  unawaited(_initNotifications(alerts));

  runApp(FoxoryApp(prefs: prefs, dbHelper: dbHelper, alerts: alerts));
}

/// Initialises notifications in the background.
///
/// Deliberately does NOT request permission. The old code called
/// Permission.notification.request() before the first frame, wrapped in a 10s
/// timeout that swallowed the result - so if the dialog never appeared,
/// notifications were silently off and the user had no way to find out or fix
/// it. Permission is now requested from Settings, where the state is visible
/// and recoverable.
Future<void> _initNotifications(AlertService alerts) async {
  const timeout = Duration(seconds: 10);

  Future<void> guard(Future<void> work) async {
    try {
      await Future.any([work, Future.delayed(timeout)]);
    } catch (_) {
      // Non-fatal: the app runs fine without notifications.
    }
  }

  await guard(alerts.init());
  await guard(alerts.ensureChannel());
  await guard(alerts.scheduleDailyCheck());
}