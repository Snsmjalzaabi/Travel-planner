// Which trip an expense defaults to. This matters because expenses used to
// default to "No trip", which silently meant they counted towards no budget.
import 'package:flutter_test/flutter_test.dart';
import 'package:your_travel_buddy/models/models.dart';
import 'package:your_travel_buddy/services/budget_service.dart';

Trip trip(
  String name, {
  required DateTime departure,
  required DateTime returnDate,
  DateTime? updatedAt,
}) =>
    Trip(
      id: name.hashCode & 0x7fffffff,
      name: name,
      originName: 'Abu Dhabi',
      originCountry: 'AE',
      destName: name,
      destCountry: 'UZ',
      departure: departure,
      returnDate: returnDate,
      transport: 'flight',
      updatedAt: updatedAt ?? departure,
    );

void main() {
  final now = DateTime(2026, 11, 10, 9, 0);

  test('picks the trip you are currently on', () {
    final current = trip('Current', departure: now.subtract(const Duration(days: 2)), returnDate: now.add(const Duration(days: 4)));
    final future = trip('Future', departure: now.add(const Duration(days: 30)), returnDate: now.add(const Duration(days: 40)));

    expect(defaultTripFor([future, current], now: now)?.name, 'Current');
  });

  test('picks the next trip when none has started', () {
    final soon = trip('Soon', departure: now.add(const Duration(days: 5)), returnDate: now.add(const Duration(days: 12)));
    final later = trip('Later', departure: now.add(const Duration(days: 40)), returnDate: now.add(const Duration(days: 50)));

    expect(defaultTripFor([later, soon], now: now)?.name, 'Soon');
  });

  test('picks the most recently updated when everything is past', () {
    final old = trip(
      'Old',
      departure: now.subtract(const Duration(days: 200)),
      returnDate: now.subtract(const Duration(days: 190)),
      updatedAt: now.subtract(const Duration(days: 190)),
    );
    final recent = trip(
      'Recent',
      departure: now.subtract(const Duration(days: 100)),
      returnDate: now.subtract(const Duration(days: 90)),
      updatedAt: now.subtract(const Duration(days: 90)),
    );

    expect(defaultTripFor([old, recent], now: now)?.name, 'Recent');
  });

  test('a trip departing exactly now counts as current, not upcoming', () {
    final boundary = trip('Boundary', departure: now, returnDate: now.add(const Duration(days: 5)));
    expect(defaultTripFor([boundary], now: now)?.name, 'Boundary');
  });

  test('a trip returning exactly now is no longer current', () {
    final ending = trip('Ending', departure: now.subtract(const Duration(days: 5)), returnDate: now);
    final next = trip('Next', departure: now.add(const Duration(days: 10)), returnDate: now.add(const Duration(days: 20)));
    expect(defaultTripFor([ending, next], now: now)?.name, 'Next');
  });

  test('an active trip wins over an earlier-departing past trip', () {
    final past = trip('Past', departure: now.subtract(const Duration(days: 100)), returnDate: now.subtract(const Duration(days: 90)));
    final active = trip('Active', departure: now.subtract(const Duration(days: 3)), returnDate: now.add(const Duration(days: 3)));
    expect(defaultTripFor([past, active], now: now)?.name, 'Active');
  });

  test('returns null when there are no trips', () {
    expect(defaultTripFor([], now: now), isNull);
  });

  test('always returns one of the given trips', () {
    final trips = [
      trip('A', departure: now.add(const Duration(days: 10)), returnDate: now.add(const Duration(days: 20))),
      trip('B', departure: now.add(const Duration(days: 30)), returnDate: now.add(const Duration(days: 40))),
    ];
    final picked = defaultTripFor(trips, now: now);
    expect(trips.map((t) => t.name), contains(picked!.name));
  });
}