// Verifies planner item lifecycle: add -> counted -> edited -> deleted.
// The planner was write-only before, so delete/edit were never exercised.
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
    dir = (await Directory.systemTemp.createTemp('foxory_plan')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'plan.db');
    await DatabaseHelper().close();
  });

  Future<int> seedTrip(DatabaseHelper h) async {
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
      'transport_type': 'flight',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  test('added planner items appear in the counts and in the loaded lists', () async {
    final h = DatabaseHelper();
    final tripId = await seedTrip(h);
    final now = DateTime.now();

    await h.insert('hotels', {
      'trip_id': tripId,
      'name': 'Hotel Tashkent',
      'address': 'Amir Timur Ave',
      'city': 'Tashkent',
      'country': 'UZ',
      'check_in': now.toIso8601String(),
      'check_out': now.add(const Duration(days: 2)).toIso8601String(),
      'confirmation_number': 'HT-99',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await h.insert('itinerary_days', {
      'trip_id': tripId,
      'day_number': 1,
      'date': now.toIso8601String(),
      'theme': 'Old town',
      'notes': 'Registan',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    await h.insert('packing_items', {
      'trip_id': tripId,
      'category': 'Documents',
      'name': 'Passport',
      'quantity': 1,
      'packed': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    final trip = (await h.loadTripsWithRelations()).single;
    expect(trip.tripHotels.length, 1);
    expect(trip.itineraryDays.length, 1);
    expect(trip.packingItems.length, 1);
    expect(trip.tripHotels.first.confirmationNumber, 'HT-99');
    expect(trip.itineraryDays.first.theme, 'Old town');
  });

  test('editing an item updates the loaded list, not just the DB', () async {
    final h = DatabaseHelper();
    final tripId = await seedTrip(h);
    final now = DateTime.now();
    final hotelId = await h.insert('hotels', {
      'trip_id': tripId,
      'name': 'Wrong Name',
      'address': '',
      'city': 'Tashkent',
      'country': 'UZ',
      'check_in': now.toIso8601String(),
      'check_out': now.add(const Duration(days: 1)).toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await h.update('hotels', {
      'name': 'Corrected Hotel',
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [hotelId]);

    final trip = (await h.loadTripsWithRelations()).single;
    expect(trip.tripHotels.first.name, 'Corrected Hotel');
  });

  test('deleting an item removes it and drops the count to zero', () async {
    final h = DatabaseHelper();
    final tripId = await seedTrip(h);
    final now = DateTime.now();
    await h.insert('packing_items', {
      'trip_id': tripId,
      'category': 'Clothes',
      'name': 'Sweater',
      'quantity': 1,
      'packed': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    expect((await h.loadTripsWithRelations()).single.packingItems.length, 1);

    await h.delete('packing_items', where: 'trip_id = ?', whereArgs: [tripId]);

    expect((await h.loadTripsWithRelations()).single.packingItems.length, 0);
  });

  test('toggling packed persists across reloads', () async {
    final h = DatabaseHelper();
    final tripId = await seedTrip(h);
    final now = DateTime.now();
    final itemId = await h.insert('packing_items', {
      'trip_id': tripId,
      'category': 'Clothes',
      'name': 'Boots',
      'quantity': 1,
      'packed': 0,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    await h.update('packing_items', {'packed': 1}, where: 'id = ?', whereArgs: [itemId]);

    final item = (await h.loadTripsWithRelations()).single.packingItems.first;
    expect(item.packed, isTrue);
    expect(item.name, 'Boots');
  });

  test('deleting a trip does not orphan its child rows into other trips', () async {
    final h = DatabaseHelper();
    final tripA = await seedTrip(h);
    final now = DateTime.now();
    final second = await h.insert('trips', {
      'name': 'Second Trip',
      'origin_name': 'Dubai',
      'origin_country': 'AE',
      'dest_name': 'Dubai',
      'dest_country': 'AE',
      'departure': now.toIso8601String(),
      'return_date': now.add(const Duration(days: 2)).toIso8601String(),
      'transport_type': 'flight',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    for (final id in [tripA, second]) {
      await h.insert('packing_items', {
        'trip_id': id,
        'category': 'Misc',
        'name': 'Item for $id',
        'quantity': 1,
        'packed': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    }

    await h.delete('trips', where: 'id = ?', whereArgs: [tripA]);
    await h.delete('packing_items', where: 'trip_id = ?', whereArgs: [tripA]);

    final remaining = await h.loadTripsWithRelations();
    expect(remaining.length, 1);
    expect(remaining.single.packingItems.length, 1);
    expect(remaining.single.packingItems.first.name, 'Item for $second');
  });
}
