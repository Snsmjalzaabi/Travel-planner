import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../core/database_helper.dart';

/// Alert service for passport expiry, visa expiry, and trip reminders.
///
/// Wakes up once per day, queries the DB for documents whose
/// `expiring_soon` or `expired` flags are set, and fires one
/// notification per record.
///
/// Android 13+ requires runtime notification permission before
/// any notification can fire. iOS requires a prompt too.
/// Call [requestPermission] at a natural moment (first launch,
/// settings screen) before relying on notifications.
class AlertService {
  static AlertService? _instance;

  static AlertService? get instance => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final DatabaseHelper _db;
  static const _channelId = 'foxory_alerts';
  static const _channelName = 'Foxory travel alerts';
  static const _dailyAlarmId = 1;

  static const _tripReminderDays = 3; // notify N days before departure

  AlertService(this._db) {
    _instance = this;
  }

  /// One-time plugin setup. Call before any notification is scheduled
  /// or fired. Safe to call multiple times.
  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dubai'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
  }

  /// Request notification permission at runtime.
  /// Returns true when notifications can fire.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    if (Platform.isIOS) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  /// Create the notification channel on Android (no-op on iOS).
  /// Call once after [init]; safe to call multiple times.
  Future<void> ensureChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Trip, passport, and visa alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Schedule a daily alarm that fires at [hour]:[minute] local time.
  /// The callback queries the DB and fires notifications.
  Future<void> scheduleDailyCheck({int hour = 8, int minute = 0}) async {
    await _plugin.zonedSchedule(
      _dailyAlarmId,
      'Daily Foxory check',
      'Checking your travel documents and reminders.',
      _nextInstanceOf(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Trip, passport, and visa alerts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var next =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Fire today's alerts immediately. Used for testing and for
  /// "sync now" style manual triggers.
  Future<int> fireAlertsNow() async {
    final alerts = await _fetchTodayAlerts();
    for (final a in alerts) {
      await _fireOne(a);
    }
    return alerts.length;
  }

  Future<List<AlertRecord>> _fetchTodayAlerts() async {
    final db = await _db.database;
    final alerts = <AlertRecord>[];

    // Passports: expiring soon or expired
    final passportRows = await db.query(
      'passports',
      where: 'expiring_soon = 1 OR expired = 1',
      orderBy: 'expiry_date ASC',
    );
    for (final r in passportRows) {
      final country = (r['country'] ?? 'Unknown') as String;
      final number = (r['passport_number'] ?? '') as String;
      final expiryStr = r['expiry_date'] as String?;
      final isExpired = (r['expired'] as int? ?? 0) == 1;
      alerts.add(AlertRecord(
        title: isExpired ? 'Passport expired' : 'Passport expiring soon',
        body: '$country passport $number${isExpired ? ' has expired' : ' is expiring soon'}${expiryStr != null ? ' — $expiryStr' : ''}',
      ));
    }

    // Visas: approved and expiring within 7 days
    // Approved visas expiring within 45 days. The 7-day window was too tight
    // to be useful — a visa you cannot act on in a week is noise.
    final visaRows = await db.query(
      'visas',
      where: "status = ? AND expiry_date IS NOT NULL AND date(expiry_date) <= date('now', '+45 days')",
      whereArgs: ['approved'],
      orderBy: 'expiry_date ASC',
    );
    for (final r in visaRows) {
      final country = (r['country'] ?? 'Unknown') as String;
      final visaType = (r['visa_type'] ?? '') as String;
      final expiryStr = r['expiry_date'] as String?;
      final hasExpiry = expiryStr != null;
      final expiry = hasExpiry ? DateTime.tryParse(expiryStr) : null;
      final daysLeft = expiry != null ? expiry.difference(DateTime.now()).inDays : 0;
      alerts.add(AlertRecord(
        title: daysLeft <= 0 ? 'Visa expired' : 'Visa expiring soon',
        body: '$country $visaType visa${daysLeft <= 0 ? ' has expired' : ' expires in $daysLeft day${daysLeft == 1 ? "" : "s"}'}${hasExpiry ? " — $expiryStr" : ""}',
      ));
    }

    // Trips departing within the next N days
    final tripRows = await db.query(
      'trips',
      where: 'departure >= ? AND departure <= ? AND status != ?',
      whereArgs: [
        DateTime.now().toIso8601String(),
        DateTime.now().add(Duration(days: _tripReminderDays)).toIso8601String(),
        'COMPLETED',
      ],
      orderBy: 'departure ASC',
    );
    for (final r in tripRows) {
      final name = (r['name'] ?? 'Trip') as String;
      final dest = (r['destName'] ?? '') as String;
      final depStr = r['departure'] as String?;
      final dep = depStr != null ? DateTime.tryParse(depStr) : null;
      final daysLeft = dep != null ? dep.difference(DateTime.now()).inDays : 0;
      alerts.add(AlertRecord(
        title: daysLeft <= 0 ? 'Trip departs today!' : 'Trip departing in $daysLeft day${daysLeft == 1 ? "" : "s"}',
        body: '$name — ${dep != null ? DateFormat("MMM d, y").format(dep) : ""}${dest.isNotEmpty ? " to $dest" : ""}',
      ));
    }

    return alerts;
  }

  Future<void> _fireOne(AlertRecord a) async {
    await _plugin.show(
      0,
      a.title,
      a.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Trip, passport, and visa alerts',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Cancel the daily alarm.
  Future<void> cancelDailyCheck() async {
    await _plugin.cancel(_dailyAlarmId);
  }

  /// Check whether the daily alarm is currently scheduled.
  Future<bool> isDailyCheckScheduled() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((req) => req.id == _dailyAlarmId);
  }
}

class AlertRecord {
  final String title;
  final String body;
  AlertRecord({required this.title, required this.body});
}
