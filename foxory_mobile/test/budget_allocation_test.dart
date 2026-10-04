// Per-category budget allocation maths. The user controls the split, so the
// important cases are the ones where the numbers do NOT add up: over-allocated,
// under-allocated, and money spent in a category nobody budgeted for.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:foxory_mobile/models/models.dart';
import 'package:foxory_mobile/services/budget_service.dart';
import 'package:foxory_mobile/services/currency_service.dart';
import 'package:path/path.dart' as p;

class _StubFx extends CurrencyService {
  _StubFx();
  @override
  Future<double> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    const toUsd = {'AED': 1 / 3.67, 'USD': 1.0};
    final usd = amount * (toUsd[from] ?? 1.0);
    const fromUsd = {'AED': 3.67, 'USD': 1.0};
    return usd * (fromUsd[to] ?? 1.0);
  }
  @override
  Future<double> getRate(String from, String to) => convert(1, from, to);
}

Trip makeTrip({double budget = 9000, int travelers = 3, int nights = 6}) {
  final now = DateTime.now();
  return Trip(
    id: 1,
    name: 'Uzbek',
    originName: 'Abu Dhabi',
    originCountry: 'AE',
    destName: 'Tashkent',
    destCountry: 'UZ',
    departure: now,
    returnDate: now.add(Duration(days: nights)),
    travelers: travelers,
    baseCurrency: 'AED',
    transport: 'flight',
    totalBudget: budget,
  );
}

Expense spend(int id, double usd, String category) => Expense(
      id: id,
      tripId: 1,
      title: 'Expense $id',
      category: category,
      amount: usd,
      currency: 'USD',
      baseAmount: usd,
      date: DateTime.now(),
    );

void main() {
  const service = BudgetService();

  Future<BudgetBreakdown> totals(List<Expense> expenses, {double budget = 9000}) =>
      service.build(makeTrip(budget: budget), expenses, currency: _StubFx());

  group('allocation maths', () {
    test('allocated sum and unassigned remainder', () async {
      final t = await totals([spend(1, 100, 'transportation')]);
      final allocations = {'transportation': 3000.0, 'food': 2000.0};

      expect(service.totalAllocated(allocations), 5000);
      // Budget is in AED, allocations are in AED.
      expect(service.unassigned(t, allocations), 9000 - 5000);
    });

    test('over-allocation reports as negative, not clamped', () async {
      final t = await totals([]);
      final allocations = {'transportation': 6000.0, 'food': 6000.0};
      final unassigned = service.unassigned(t, allocations);
      expect(unassigned, -3000, reason: 'must show the overspend, not hide it');
    });

    test('a category over its allocation is flagged', () async {
      // Spend AED 3670 (=$1000) into a transport allocation of AED 1000.
      final t = await totals([spend(1, 1000, 'transportation')]);
      final rows = service.categoryBreakdown(
        makeTrip(),
        t,
        {'transportation': 1000.0},
      );
      final transport = rows.firstWhere((r) => r.category == 'transportation');
      expect(transport.isOver, isTrue);
      expect(transport.remaining, lessThan(0));
    });

    test('remaining and fraction are right for a category under budget', () async {
      final t = await totals([spend(1, 367, 'food')]); // AED 1346.89
      final rows = service.categoryBreakdown(makeTrip(), t, {'food': 3000.0});
      final food = rows.firstWhere((r) => r.category == 'food');

      expect(food.allocated, 3000);
      expect(food.spent, closeTo(367 * 3.67, 0.01));
      expect(food.remaining, closeTo(3000 - 367 * 3.67, 0.01));
      expect(food.isOver, isFalse);
      // spent is converted to AED (the trip currency) before the ratio,
      // so the fraction is AED-spent / AED-allocated.
      expect(food.usedFraction, closeTo((367 * 3.67) / 3000, 0.001));
    });

    test('spending in an unbudgeted category is surfaced, not hidden', () async {
      final t = await totals([spend(1, 100, 'shopping')]);
      final rows = service.categoryBreakdown(makeTrip(), t, {'food': 3000.0});

      final shopping = rows.firstWhere((r) => r.category == 'shopping');
      expect(shopping.unbudgeted, isTrue, reason: 'spent money nobody budgeted for');
      expect(shopping.hasAllocation, isFalse);
      expect(shopping.allocated, 0);
    });

    test('every category with either allocation or spend appears', () async {
      final t = await totals([
        spend(1, 50, 'food'),
        spend(2, 50, 'groceries'),
      ]);
      final rows = service.categoryBreakdown(
        makeTrip(),
        t,
        {'transportation': 2000.0, 'accommodation': 2500.0},
      );
      final names = rows.map((r) => r.category).toSet();
      expect(names, containsAll(['transportation', 'accommodation', 'food', 'groceries']));
    });

    test('allocated categories sort above unbudgeted spend', () async {
      final t = await totals([spend(1, 900, 'shopping')]);
      final rows = service.categoryBreakdown(
        makeTrip(),
        t,
        {'food': 1000.0, 'transportation': 2000.0},
      );
      expect(rows.first.hasAllocation, isTrue);
      expect(rows.last.hasAllocation, isFalse);
    });

    test('shareOf reflects the split the user chose', () async {
      final t = await totals([]);
      final rows = service.categoryBreakdown(
        makeTrip(),
        t,
        {'transportation': 3000.0, 'food': 1000.0},
      );
      final transport = rows.firstWhere((r) => r.category == 'transportation');
      final food = rows.firstWhere((r) => r.category == 'food');
      expect(transport.shareOf(4000), closeTo(0.75, 0.001));
      expect(food.shareOf(4000), closeTo(0.25, 0.001));
    });

    test('no budget set still computes what was spent', () async {
      final t = await totals([spend(1, 100, 'food')], budget: 0);
      expect(t.hasBudget, isFalse);
      final rows = service.categoryBreakdown(makeTrip(budget: 0), t, {'food': 500.0});
      expect(rows.first.spent, closeTo(367, 0.01));
    });
  });

  group('allocation storage', () {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    late String dir;
    late DatabaseHelper h;

    setUp(() async {
      dir = (await Directory.systemTemp.createTemp('foxory_alloc')).path;
      DatabaseHelper.testOverridePath = p.join(dir, 'a.db');
      h = DatabaseHelper();
      await h.close();
    });

    Future<int> seedTrip() async {
      final now = DateTime.now();
      return h.insert('trips', {
        'name': 'Uzbek',
        'origin_name': 'Abu Dhabi',
        'origin_country': 'AE',
        'dest_name': 'Tashkent',
        'dest_country': 'UZ',
        'departure': now.toIso8601String(),
        'return_date': now.add(const Duration(days: 6)).toIso8601String(),
        'transport_type': 'flight',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    test('allocations round-trip', () async {
      final id = await seedTrip();
      await h.setBudgetAllocation(id, 'transportation', 3000);
      await h.setBudgetAllocation(id, 'food', 1500.5);

      final allocs = await h.getBudgetAllocations(id);
      expect(allocs['transportation'], 3000);
      expect(allocs['food'], 1500.5);
    });

    test('setting the same category twice updates rather than duplicating', () async {
      final id = await seedTrip();
      await h.setBudgetAllocation(id, 'food', 1000);
      await h.setBudgetAllocation(id, 'food', 2000);

      final allocs = await h.getBudgetAllocations(id);
      expect(allocs.length, 1);
      expect(allocs['food'], 2000);

      final rows = await h.queryAll('trip_budgets');
      expect(rows.length, 1);
    });

    test('setting zero soft-deletes the allocation', () async {
      final id = await seedTrip();
      await h.setBudgetAllocation(id, 'food', 1000);
      await h.setBudgetAllocation(id, 'food', 0);

      expect(await h.getBudgetAllocations(id), isEmpty);
      // Row survives so the removal syncs rather than vanishing.
      expect(await h.queryAll('trip_budgets'), hasLength(1));
    });

    test('allocations are per trip, not global', () async {
      final now = DateTime.now();
      final a = await seedTrip();
      final b = await h.insert('trips', {
        'name': 'Other',
        'origin_name': 'Dubai',
        'origin_country': 'AE',
        'dest_name': 'Tokyo',
        'dest_country': 'JP',
        'departure': now.toIso8601String(),
        'return_date': now.add(const Duration(days: 3)).toIso8601String(),
        'transport_type': 'flight',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      await h.setBudgetAllocation(a, 'food', 1000);
      await h.setBudgetAllocation(b, 'food', 500);

      expect((await h.getBudgetAllocations(a))['food'], 1000);
      expect((await h.getBudgetAllocations(b))['food'], 500);
    });

    test('trip_budgets takes part in sync', () {
      // Unlike app_files, allocations are plain numbers with no device-local
      // paths, so they belong in the Pi backup.
      expect(DatabaseHelper.syncTables.contains('trip_budgets'), isTrue);
    });

    test('every sync table including trip_budgets has deleted_at', () async {
      final db = await h.database;
      for (final table in DatabaseHelper.syncTables) {
        final cols = (await db.rawQuery('PRAGMA table_info($table)'))
            .map((c) => c['name'] as String)
            .toSet();
        expect(cols.contains('deleted_at'), isTrue, reason: '$table needs deleted_at');
      }
    });
  });
}