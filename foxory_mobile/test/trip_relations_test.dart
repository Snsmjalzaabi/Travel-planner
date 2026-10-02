// Verifies loadTripsWithRelations() attaches real rows and that counts match.
// Run: flutter test
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_test')).path;
    // Point DatabaseHelper at a throwaway DB per test.
    DatabaseHelper.testOverridePath = p.join(dir, 'foxory_test.db');
    await DatabaseHelper().close();
  });

  test('loadTripsWithRelations returns empty relations, not null', () async {
    final helper = DatabaseHelper();
    await helper.insert('trips', {
      'name': 'Solo Trip',
      'origin_name': 'Dubai',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': DateTime.now().toIso8601String(),
      'return_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      'transport_type': 'flight',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final trips = await helper.loadTripsWithRelations();
    expect(trips.length, 1);
    // The old getters returned null; these must be empty lists, never null.
    expect(trips.first.hotels, isNotNull);
    expect(trips.first.hotels, isEmpty);
    expect(trips.first.flights, isEmpty);
    expect(trips.first.itineraryDays, isEmpty);
    expect(trips.first.packingItems, isEmpty);
  });

  test('relations are populated and counts are accurate', () async {
    final helper = DatabaseHelper();
    final id = await helper.insert('trips', {
      'name': 'Uzbek',
      'origin_name': 'Abu Dhabi',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': DateTime.now().toIso8601String(),
      'return_date': DateTime.now().add(const Duration(days: 6)).toIso8601String(),
      'travelers': 3,
      'transport_type': 'flight',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await helper.insert('hotels', {
      'trip_id': id,
      'name': 'Hotel Tashkent',
      'address': 'Amir Timur',
      'city': 'Tashkent',
      'country': 'UZ',
      'check_in': DateTime.now().toIso8601String(),
      'check_out': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await helper.insert('flights', {
      'trip_id': id,
      'airline': 'Flydubai',
      'flight_number': 'FZ1234',
      'from_city': 'Abu Dhabi',
      'from_country': 'AE',
      'to_city': 'Tashkent',
      'to_country': 'UZ',
      'departure': DateTime.now().toIso8601String(),
      'arrival': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await helper.insert('itinerary_days', {
      'trip_id': id,
      'day_number': 1,
      'date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
    await helper.insert('packing_items', {
      'trip_id': id,
      'category': 'Clothes',
      'name': 'Passport',
      'quantity': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final trips = await helper.loadTripsWithRelations();
    expect(trips.length, 1);
    final trip = trips.first;

    // This is the bug being fixed: these all read 0 even with data saved.
    expect(trip.tripHotels.length, 1);
    expect(trip.tripFlights.length, 1);
    expect(trip.itineraryDays.length, 1);
    expect(trip.packingItems.length, 1);

    // And the data itself must be intact, not just counted.
    expect(trip.tripHotels.first.name, 'Hotel Tashkent');
    expect(trip.tripFlights.first.airline, 'Flydubai');
    expect(trip.packingItems.first.name, 'Passport');
    expect(trip.travelers, 3);
  });
}
