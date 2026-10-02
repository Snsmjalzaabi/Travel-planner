/// Per-trip budget maths. Pure functions over already-fetched rows — no I/O,
/// so it is trivially testable and cheap to call on every rebuild.
///
/// Money model: `expenses.base_amount` is stored canonically in USD (see
/// CurrencyService). Every figure here converts USD → the trip's currency for
/// display, so a trip budgeted in EUR or UZS still reports correctly.
library;

import 'package:intl/intl.dart';
import '../models/models.dart';
import 'currency_service.dart';

class BudgetBreakdown {
  final Trip trip;

  /// Trip's total budget, in the trip's own currency.
  final double budget;

  /// Expenses attached to this trip, converted to trip currency.
  final double spent;

  final double remaining;
  final double perTravellerBudget;
  final double perTravellerSpent;
  final int travellerCount;
  final int tripDays;

  /// Spend per day in trip currency. Null when the trip has no date range.
  final double? perDayBudget;
  final double? perDaySpent;

  /// Expense total grouped by category, in trip currency.
  final Map<String, double> byCategory;

  /// True when spend exceeds budget. Also true when budget is 0 but spend > 0,
  /// because that is still worth surfacing.
  final bool isOverBudget;

  /// 0..1. Null when no budget is set.
  final double? usedFraction;

  /// True when a budget is set.
  final bool hasBudget;

  const BudgetBreakdown({
    required this.trip,
    required this.budget,
    required this.spent,
    required this.remaining,
    required this.perTravellerBudget,
    required this.perTravellerSpent,
    required this.travellerCount,
    required this.tripDays,
    required this.perDayBudget,
    required this.perDaySpent,
    required this.byCategory,
    required this.isOverBudget,
    required this.usedFraction,
    required this.hasBudget,
  });
}

class BudgetService {
  const BudgetService();

  /// Builds a breakdown for [trip] from its expenses.
  ///
  /// [expenses] may include rows from other trips; only those whose trip_id
  /// matches are counted, so a caller can pass one unfiltered query.
  Future<BudgetBreakdown> build(
    Trip trip,
    List<Expense> expenses, {
    CurrencyService? currency,
  }) async {
    final fx = currency ?? CurrencyService();
    final toTrip = (double usd) async =>
        trip.baseCurrency == 'USD' ? usd : await fx.convert(usd, 'USD', trip.baseCurrency);

    final mine = expenses.where((e) => e.tripId == trip.id).toList();

    var spentUsd = 0.0;
    final catUsd = <String, double>{};
    for (final e in mine) {
      // base_amount is the canonical USD figure. Fall back to converting the
      // raw amount for rows written before base_amount existed.
      final usd = e.baseAmount ?? await fx.convert(e.amount, e.currency, 'USD');
      spentUsd += usd;
      final cat = e.category.isEmpty ? 'other' : e.category;
      catUsd[cat] = (catUsd[cat] ?? 0) + usd;
    }

    final spent = await toTrip(spentUsd);
    final budget = trip.totalBudget;
    final travellers = trip.travelers <= 0 ? 1 : trip.travelers;
    final days = trip.nights > 0 ? trip.nights : 1;
    final hasBudget = budget > 0;

    final byCategory = <String, double>{};
    for (final entry in catUsd.entries) {
      byCategory[entry.key] = await toTrip(entry.value);
    }

    return BudgetBreakdown(
      trip: trip,
      budget: budget,
      spent: spent,
      remaining: budget - spent,
      perTravellerBudget: hasBudget ? budget / travellers : 0,
      perTravellerSpent: spent / travellers,
      travellerCount: travellers,
      tripDays: days,
      perDayBudget: hasBudget ? budget / days : null,
      perDaySpent: spent / days,
      byCategory: byCategory,
      isOverBudget: hasBudget ? spent > budget : spent > 0,
      usedFraction: hasBudget ? (spent / budget) : null,
      hasBudget: hasBudget,
    );
  }

  /// Sum of every expense in the database, ignoring trip association.
  /// Used for the overall dashboard figure.
  Future<double> totalForAll(List<Expense> expenses, {CurrencyService? currency}) async {
    final fx = currency ?? CurrencyService();
    var usd = 0.0;
    for (final e in expenses) {
      usd += e.baseAmount ?? await fx.convert(e.amount, e.currency, 'USD');
    }
    return usd;
  }
}

/// Shared currency formatting so budget figures match the rest of the app.
String formatMoney(double amount, String currency) {
  final symbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'INR': '₹',
    'UZS': 'soʻm',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'SGD': 'S\$',
    'AUD': 'A\$',
    'CAD': 'C\$',
  };
  final symbol = symbols[currency.toUpperCase()] ?? currency.toUpperCase();
  return NumberFormat.currency(symbol: symbol, decimalDigits: amount >= 1000 ? 0 : 2).format(amount);
}
