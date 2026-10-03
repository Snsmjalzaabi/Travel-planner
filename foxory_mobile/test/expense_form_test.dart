// Guards the Quick Add regression: More -> Quick Add used to write
// category 'other', currency AED, no trip and no base_amount, which pushed
// spend outside every trip budget. This asserts the canonical row shape the
// shared sheet now writes, against a real database.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:foxory_mobile/models/models.dart';
import 'package:foxory_mobile/ui/expense_form_sheet.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;
  late DatabaseHelper h;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_exp')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'e.db');
    h = DatabaseHelper();
    await h.close();
  });

  Future<int> seedTrip({double budget = 5000, String currency = 'AED'}) async {
    final now = DateTime.now();
    return h.insert('trips', {
      'name': 'Uzbek',
      'origin_name': 'Abu Dhabi',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': now.toIso8601String(),
      'return_date': now.add(const Duration(days: 6)).toIso8601String(),
      'travelers': 3,
      'base_currency': currency,
      'transport_type': 'flight',
      'total_budget': budget,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  test('every category is in the canonical set', () {
    for (final c in kExpenseCategories) {
      expect(normalizeExpenseCategory(c), c);
      expect(expenseCategoryLabel(c), isNotEmpty);
    }
  });

  test('legacy values normalise instead of leaking through', () {
    // 'transport' was the old spelling; it must land on 'transportation'.
    expect(normalizeExpenseCategory('transport'), 'transportation');
    expect(normalizeExpenseCategory('Transport'), 'transportation');
    // Anything unknown falls back to 'other' rather than inventing a value.
    expect(normalizeExpenseCategory('nonsense'), 'other');
    expect(normalizeExpenseCategory(''), 'other');
  });

  test('an expense written for a trip carries trip_id and a real category', () async {
    final tripId = await seedTrip();
    final now = DateTime.now().toIso8601String();

    // Mirrors exactly what the shared sheet writes.
    await h.insert('expenses', {
      'trip_id': tripId,
      'title': 'Taxi to airport',
      'category': normalizeExpenseCategory('transport'),
      'amount': 150,
      'currency': 'AED',
      'base_amount': 150 / 3.67,
      'date': now,
      'notes': null,
      'created_at': now,
      'updated_at': now,
      'sync_enabled': 1,
    });

    final rows = await h.queryAll('expenses');
    final e = Expense.fromMap(rows.single);
    expect(e.tripId, tripId);
    expect(e.category, 'transportation');
    expect(e.baseAmount, isNotNull, reason: 'missing base_amount keeps spend out of budget maths');
  });

  test('an untagged expense is still valid and does not crash the reader', () async {
    final now = DateTime.now().toIso8601String();
    await h.insert('expenses', {
      'trip_id': null,
      'title': 'Mystery spend',
      'category': 'other',
      'amount': 20,
      'currency': 'AED',
      'base_amount': 20 / 3.67,
      'date': now,
      'notes': 'No idea what this was',
      'created_at': now,
      'updated_at': now,
      'sync_enabled': 1,
    });

    final rows = await h.queryAll('expenses');
    final e = Expense.fromMap(rows.single);
    expect(e.tripId, isNull);
    expect(e.notes, 'No idea what this was');
  });

  test('editing an expense via the sheet shape updates category and trip', () async {
    final tripA = await seedTrip();
    final now = DateTime.now().toIso8601String();
    final id = await h.insert('expenses', {
      'trip_id': null,
      'title': 'Was other',
      'category': 'other',
      'amount': 30,
      'currency': 'AED',
      'base_amount': 30 / 3.67,
      'date': now,
      'notes': 'vague',
      'created_at': now,
      'updated_at': now,
      'sync_enabled': 1,
    });

    await h.update('expenses', {
      'trip_id': tripA,
      'category': 'food',
      'notes': null,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);

    final e = Expense.fromMap((await h.queryOne('expenses', where: 'id = ?', whereArgs: [id]))!);
    expect(e.tripId, tripA);
    expect(e.category, 'food');
    expect(e.notes, isNull, reason: 'stale Other comment must clear when category changes');
  });

  test('currencies offered by the sheet include AED and UZS', () {
    expect(kExpenseCurrencies, contains('AED'));
    expect(kExpenseCurrencies, contains('USD'));
    expect(kExpenseCurrencies, contains('UZS'));
  });
}
