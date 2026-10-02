// Budget maths against real rows. CurrencyService is stubbed so the tests are
// deterministic and do no network calls — exchange rates are not what is
// under test here, the arithmetic is.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:foxory_mobile/models/models.dart';
import 'package:foxory_mobile/services/budget_service.dart';
import 'package:foxory_mobile/services/currency_service.dart';
import 'package:path/path.dart' as p;

/// Fixed rates: USD->AED 3.67, USD->EUR 0.92, USD->UZS 12600.
class _StubFx extends CurrencyService {
  _StubFx();

  @override
  Future<double> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    const toUsd = {'AED': 1 / 3.67, 'EUR': 1 / 0.92, 'UZS': 1 / 12600, 'USD': 1.0};
    final usd = amount * (toUsd[from] ?? 1.0);
    const fromUsd = {'AED': 3.67, 'EUR': 0.92, 'UZS': 12600, 'USD': 1.0};
    return usd * (fromUsd[to] ?? 1.0);
  }

  @override
  Future<double> getRate(String from, String to) => convert(1, from, to);
}

Trip makeTrip({
  int id = 1,
  String currency = 'AED',
  double budget = 5000,
  int travelers = 3,
  int nights = 6,
}) {
  final now = DateTime.now();
  return Trip(
    id: id,
    name: 'Uzbek',
    originName: 'Abu Dhabi',
    originCountry: 'AE',
    destName: 'Tashkent',
    destCountry: 'UZ',
    departure: now,
    returnDate: now.add(Duration(days: nights)),
    travelers: travelers,
    baseCurrency: currency,
    transport: 'flight',
    totalBudget: budget,
  );
}

Expense makeExpense({
  int id = 1,
  int? tripId = 1,
  double amount = 100,
  String currency = 'USD',
  double? baseUsd,
  String category = 'food',
}) {
  return Expense(
    id: id,
    tripId: tripId,
    title: 'Expense $id',
    category: category,
    amount: amount,
    currency: currency,
    baseAmount: baseUsd,
    date: DateTime.now(),
  );
}

void main() {
  test('spend is summed from base_amount in USD then converted to trip currency', () async {
    final trip = makeTrip(currency: 'AED', budget: 5000);
    final expenses = [
      makeExpense(id: 1, baseUsd: 100), // $100
      makeExpense(id: 2, baseUsd: 50, category: 'transportation'), // $50
    ];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());

    expect(d.spent, closeTo(150 * 3.67, 0.01)); // AED 550.50
    expect(d.budget, 5000);
    expect(d.remaining, closeTo(5000 - 150 * 3.67, 0.01));
  });

  test('expenses belonging to other trips are excluded', () async {
    final trip = makeTrip();
    final expenses = [
      makeExpense(id: 1, tripId: 1, baseUsd: 100),
      makeExpense(id: 2, tripId: 2, baseUsd: 999), // different trip
      makeExpense(id: 3, tripId: null, baseUsd: 500), // untagged
    ];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.spent, closeTo(100 * 3.67, 0.01));
  });

  test('per-person and per-day split correctly', () async {
    final trip = makeTrip(currency: 'AED', budget: 5100, travelers: 3, nights: 6);
    final expenses = [makeExpense(baseUsd: 300)];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());

    final spentAed = 300 * 3.67;
    expect(d.perTravellerSpent, closeTo(spentAed / 3, 0.01));
    expect(d.perTravellerBudget, closeTo(5100 / 3, 0.01));
    expect(d.perDaySpent, closeTo(spentAed / 6, 0.01));
    expect(d.perDayBudget, closeTo(5100 / 6, 0.01));
  });

  test('going over budget is detected', () async {
    final trip = makeTrip(currency: 'AED', budget: 100);
    final expenses = [makeExpense(baseUsd: 100)]; // AED 367 > AED 100

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.isOverBudget, isTrue);
    expect(d.remaining, lessThan(0));
    expect(d.usedFraction, greaterThan(1.0));
  });

  test('under budget reports a sane fraction and no overage', () async {
    final trip = makeTrip(currency: 'AED', budget: 3670); // exactly $1000
    final expenses = [makeExpense(baseUsd: 250)]; // $250 = AED 917.50

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.isOverBudget, isFalse);
    expect(d.usedFraction, closeTo(0.25, 0.001));
    expect(d.remaining, closeTo(3670 - 250 * 3.67, 0.01));
  });

  test('no budget set still reports spend and flags it', () async {
    final trip = makeTrip(currency: 'AED', budget: 0);
    final expenses = [makeExpense(baseUsd: 20)];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.hasBudget, isFalse);
    expect(d.usedFraction, isNull);
    expect(d.perDayBudget, isNull);
    // Spending against an unbudgeted trip is still worth surfacing.
    expect(d.isOverBudget, isTrue);
    expect(d.spent, closeTo(20 * 3.67, 0.01));
  });

  test('category breakdown groups and totals match the grand total', () async {
    final trip = makeTrip(currency: 'AED');
    final expenses = [
      makeExpense(id: 1, baseUsd: 100, category: 'food'),
      makeExpense(id: 2, baseUsd: 50, category: 'food'),
      makeExpense(id: 3, baseUsd: 30, category: 'transportation'),
    ];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.byCategory['food'], closeTo(150 * 3.67, 0.01));
    expect(d.byCategory['transportation'], closeTo(30 * 3.67, 0.01));
    final sum = d.byCategory.values.fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(d.spent, 0.01));
  });

  test('a non-USD trip currency converts the whole breakdown', () async {
    final trip = makeTrip(currency: 'UZS', budget: 12_600_000); // $1000
    final expenses = [makeExpense(baseUsd: 200)];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.spent, closeTo(200 * 12600, 1)); // UZS 2,520,000
    expect(d.usedFraction, closeTo(0.2, 0.001));
  });

  test('expenses with no base_amount fall back to converting the raw amount', () async {
    final trip = makeTrip(currency: 'AED');
    // Legacy row: baseUsd is null, amount is 100 AED.
    final expenses = [Expense(
      id: 1,
      tripId: 1,
      title: 'Legacy',
      category: 'other',
      amount: 100,
      currency: 'AED',
      date: DateTime.now(),
    )];

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    // 100 AED -> USD -> back to AED = 100
    expect(d.spent, closeTo(100, 0.01));
  });

  test('DB round-trip preserves trip_id so spend lands on the right trip', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = (await Directory.systemTemp.createTemp('foxory_budget')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'b.db');
    final h = DatabaseHelper();
    await h.close();

    final now = DateTime.now();
    final tripId = await h.insert('trips', {
      'name': 'Uzbek',
      'origin_name': 'Abu Dhabi',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': now.toIso8601String(),
      'return_date': now.add(const Duration(days: 6)).toIso8601String(),
      'travelers': 3,
      'base_currency': 'AED',
      'transport_type': 'flight',
      'total_budget': 5000,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await h.insert('expenses', {
      'trip_id': tripId,
      'title': 'Taxi',
      'category': 'transportation',
      'amount': 150,
      'currency': 'AED',
      'base_amount': 150 / 3.67,
      'date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    final rows = await h.queryAll('expenses');
    final expenses = rows.map(Expense.fromMap).toList();
    final trip = (await h.loadTripsWithRelations()).single;

    expect(expenses.single.tripId, tripId);
    expect(trip.totalBudget, 5000);
    expect(trip.travelers, 3);

    final d = await const BudgetService().build(trip, expenses, currency: _StubFx());
    expect(d.spent, closeTo(150, 0.5));
    expect(d.remaining, closeTo(4850, 1));
    expect(d.isOverBudget, isFalse);
  });
}
