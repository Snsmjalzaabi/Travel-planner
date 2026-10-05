// Verifies passports and visas can actually be written and read back with the
// real column names, and that expiry flags are computed correctly.
// This is the path that was silently broken by the duplicate Visa class.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_travel_buddy/core/database_helper.dart';
import 'package:your_travel_buddy/models/models.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_docs')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'docs.db');
    await DatabaseHelper().close();
  });

  Map<String, dynamic> passportRow({
    String number = 'A1234567',
    int expiryInDays = 200,
    int alertMonths = 6,
  }) {
    final now = DateTime.now();
    return {
      'passport_number': number,
      'country': 'UAE',
      'country_code': 'AE',
      'issued_date': now.subtract(const Duration(days: 365 * 3)).toIso8601String(),
      'expiry_date': now.add(Duration(days: expiryInDays)).toIso8601String(),
      'issuing_authority': 'ICP',
      'holder_name': 'Sultan Alzaabi',
      'nationality': 'UAE',
      'place_of_birth': null,
      'date_of_birth': null,
      'tax_id': null,
      'photo_path': '',
      'notes': '',
      'expiry_alert_months': alertMonths,
      'expired': 0,
      'expiring_soon': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sync_enabled': 1,
      'sync_status': 0,
    };
  }

  test('passport round-trips with all columns intact', () async {
    final helper = DatabaseHelper();
    final id = await helper.insert('passports', passportRow());

    final row = await helper.queryOne('passports', where: 'id = ?', whereArgs: [id]);
    expect(row, isNotNull);

    final p = Passport.fromMap(row!);
    expect(p.passportNumber, 'A1234567');
    expect(p.country, 'UAE');
    expect(p.countryCode, 'AE');
    expect(p.holderName, 'Sultan Alzaabi');
    expect(p.issuingAuthority, 'ICP');
    expect(p.expiryAlertMonths, 6);
  });

  test('expiry flags derive from the date, not a stale stored column', () async {
    final helper = DatabaseHelper();
    final id = await helper.insert('passports', passportRow(expiryInDays: 20, alertMonths: 6));
    final row = await helper.queryOne('passports', where: 'id = ?', whereArgs: [id]);
    final p = Passport.fromMap(row!);
    // 20 days out, inside a 6-month warning window.
    expect(p.expired, isFalse);
    expect(p.expiringSoon, isTrue);
  });

  test('already-expired passport is flagged expired', () async {
    final helper = DatabaseHelper();
    final id = await helper.insert('passports', passportRow(expiryInDays: -30));
    final row = await helper.queryOne('passports', where: 'id = ?', whereArgs: [id]);
    final p = Passport.fromMap(row!);
    expect(p.expired, isTrue);
    expect(p.expiringSoon, isFalse);
  });

  test('visa writes the columns the schema actually has', () async {
    final helper = DatabaseHelper();
    final pid = await helper.insert('passports', passportRow());
    final now = DateTime.now();

    final vid = await helper.insert('visas', {
      'passport_id': pid,
      'country': 'Uzbekistan',
      'country_code': 'UZ',
      'visa_type': 'tourist',
      'status': 'approved',
      'issued_date': now.toIso8601String(),
      'expiry_date': now.add(const Duration(days: 30)).toIso8601String(),
      'entry_date': null,
      'exit_date': null,
      'max_stay_days': 30,
      'entry_rules': 'Single entry',
      'conditions': 'Carry printed hotel confirmation',
      'cost': 45.0,
      'cost_currency': 'USD',
      'application_ref': 'UZ-REF-123',
      'notes': '',
      'photo_path': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'sync_enabled': 1,
      'sync_status': 0,
    });

    final row = await helper.queryOne('visas', where: 'id = ?', whereArgs: [vid]);
    final v = Visa.fromMap(row!);
    // These fields only exist on the passport.dart Visa. The old exported
    // visa.dart class would have thrown on fromMap here.
    expect(v.country, 'Uzbekistan');
    expect(v.countryCode, 'UZ');
    expect(v.visaType, 'tourist');
    expect(v.status, 'approved');
    expect(v.maxStayDays, 30);
    expect(v.entryRules, 'Single entry');
    expect(v.cost, 45.0);
    expect(v.passportId, pid);
    expect(v.isValid, isTrue);
  });

  test('visa expiry feeds the approved-visa alert query', () async {
    final helper = DatabaseHelper();
    final now = DateTime.now();
    await helper.insert('visas', {
      'passport_id': null,
      'country': 'Uzbekistan',
      'country_code': 'UZ',
      'visa_type': 'tourist',
      // This is the exact status the notification service filters on.
      'status': 'approved',
      'expiry_date': now.add(const Duration(days: 20)).toIso8601String(),
      'notes': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await helper.insert('visas', {
      'passport_id': null,
      'country': 'Turkey',
      'country_code': 'TR',
      'visa_type': 'tourist',
      'status': 'not_required',
      'expiry_date': now.add(const Duration(days: 20)).toIso8601String(),
      'notes': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    final db = await helper.database;
    final alerts = await db.query(
      'visas',
      where: "status = ? AND expiry_date IS NOT NULL AND date(expiry_date) <= date('now', '+45 days')",
      whereArgs: ['approved'],
      orderBy: 'expiry_date ASC',
    );
    expect(alerts.length, 1);
    expect(alerts.first['country'], 'Uzbekistan');
  });
}
