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

/// One category's slice of a trip budget.
class CategoryBudget {
  final String category;

  /// What the user set aside, in the trip's currency.
  final double allocated;

  /// What has actually been spent, in the trip's currency.
  final double spent;

  CategoryBudget({
    required this.category,
    required this.allocated,
    required this.spent,
  });

  double get remaining => allocated - spent;
  bool get hasAllocation => allocated > 0;
  bool get isOver => hasAllocation && spent > allocated;

  /// 0..1 against the allocation. Null when nothing was set aside.
  double? get usedFraction {
    if (!hasAllocation) return null;
    return spent / allocated;
  }

  /// True when money was spent in a category nobody budgeted for.
  bool get unbudgeted => !hasAllocation && spent > 0;

  /// Fraction of the *total* allocated that this slice represents.
  double shareOf(double totalAllocated) =>
      totalAllocated > 0 ? allocated / totalAllocated : 0;
}

/// A category that has spending but no allocation set for it.
class UnbudgetedSpend {
  final String category;
  final double spent;
  const UnbudgetedSpend(this.category, this.spent);
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

  /// Builds a per-category breakdown of [trip], combining the allocations the
  /// user set in [allocations] with what has actually been spent.
  ///
  /// Returns every category that either has an allocation or has spending, so
  /// nothing is silently dropped: categories with spending but no allocation
  /// come back with [CategoryBudget.unbudgeted] set.
  List<CategoryBudget> categoryBreakdown(
    Trip trip,
    BudgetBreakdown totals,
    Map<String, double> allocations,
  ) {
    final names = <String>{...allocations.keys, ...totals.byCategory.keys};
    return names.map((name) {
      final entry = CategoryBudget(
        category: name,
        allocated: allocations[name] ?? 0,
        spent: totals.byCategory[name] ?? 0,
      );
      return entry;
    }).toList()
      ..sort((a, b) {
        // Allocations first, then biggest spend.
        if (a.hasAllocation != b.hasAllocation) return a.hasAllocation ? -1 : 1;
        final byAllocated = b.allocated.compareTo(a.allocated);
        return byAllocated != 0 ? byAllocated : b.spent.compareTo(a.spent);
      });
  }

  /// Total the user has assigned across categories.
  double totalAllocated(Map<String, double> allocations) =>
      allocations.values.fold<double>(0, (a, b) => a + b);

  /// Money in the trip budget that has not been assigned to any category.
  double unassigned(BudgetBreakdown totals, Map<String, double> allocations) =>
      totals.budget - totalAllocated(allocations);

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

/// Picks which trip an expense should default to.
///
/// Without this, expenses landed with trip_id = null and silently counted
/// towards nothing - which quietly broke the whole budget picture. Order of
/// preference: the trip you are actually on, then the next one starting,
/// then the most recently updated.
Trip? defaultTripFor(List<Trip> trips, {DateTime? now}) {
  if (trips.isEmpty) return null;
  final at = now ?? DateTime.now();

  // Currently travelling: departure has passed, return date has not.
  for (final t in trips) {
    if (!t.departure.isAfter(at) && t.returnDate.isAfter(at)) return t;
  }

  // Next one to depart.
  final upcoming = trips.where((t) => t.departure.isAfter(at)).toList()
    ..sort((a, b) => a.departure.compareTo(b.departure));
  if (upcoming.isNotEmpty) return upcoming.first;

  // Everything is past - most recently updated.
  final sorted = [...trips]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return sorted.first;
}
