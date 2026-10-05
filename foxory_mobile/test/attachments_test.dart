// Booking-confirmation attachments. These pin the linking and storage rules,
// since a confirmation attached to the wrong trip is worse than no
// confirmation at all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_travel_buddy/core/database_helper.dart';
import 'package:your_travel_buddy/services/attachment_service.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;
  late DatabaseHelper h;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_att')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'a.db');
    h = DatabaseHelper();
    await h.close();
  });

  Future<int> seedTrip(String name) async {
    final now = DateTime.now();
    return h.insert('trips', {
      'name': name,
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

  Future<int> seedFlight(int tripId) async {
    final now = DateTime.now();
    return h.insert('flights', {
      'trip_id': tripId,
      'airline': 'Flydubai',
      'flight_number': 'FZ1234',
      'from_city': 'Abu Dhabi',
      'from_country': 'AE',
      'to_city': 'Tashkent',
      'to_country': 'UZ',
      'departure': now.add(const Duration(days: 5)).toIso8601String(),
      'arrival': now.add(const Duration(days: 5, hours: 4)).toIso8601String(),
      'status': 'CONFIRMED',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
  }

  /// Writes an app_files row the way AttachmentService does.
  Future<int> seedAttachment({
    required String linkedType,
    required int linkedId,
    String name = 'confirmation.pdf',
    String mime = 'application/pdf',
    int size = 2048,
    bool deleted = false,
  }) async {
    final now = DateTime.now();
    return h.insert('app_files', {
      'name': name,
      'type': mime.startsWith('image/') ? 'image' : 'document',
      'mime_type': mime,
      'file_path': p.join(dir, name),
      'file_size': size,
      'byte_count': size,
      'category': 'confirmation',
      'tags': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'linked_type': linkedType,
      'linked_id': linkedId,
      'sync_enabled': 0,
      'sync_status': 0,
      if (deleted) 'deleted_at': now.toIso8601String(),
    });
  }

  test('app_files has columns for linking to any entity', () async {
    final db = await h.database;
    final cols = (await db.rawQuery('PRAGMA table_info(app_files)'))
        .map((c) => c['name'] as String)
        .toSet();
    expect(cols.contains('linked_type'), isTrue);
    expect(cols.contains('linked_id'), isTrue);
    expect(cols.contains('deleted_at'), isTrue);
  });

  test('an attachment is linked to exactly one flight', () async {
    final tripId = await seedTrip('Uzbek');
    final flightId = await seedFlight(tripId);
    await seedAttachment(linkedType: 'flight', linkedId: flightId);

    final rows = await h.queryAll('app_files');
    expect(rows.length, 1);
    expect(rows.first['linked_type'], 'flight');
    expect(rows.first['linked_id'], flightId);
  });

  test('attachments do not leak between flights', () async {
    final tripId = await seedTrip('Uzbek');
    final a = await seedFlight(tripId);
    final b = await seedFlight(tripId);
    await seedAttachment(linkedType: 'flight', linkedId: a, name: 'flight-a.pdf');

    final forA = await h.queryAll(
      'app_files',
      where: 'linked_type = ? AND linked_id = ? AND deleted_at IS NULL',
      whereArgs: ['flight', a],
    );
    final forB = await h.queryAll(
      'app_files',
      where: 'linked_type = ? AND linked_id = ? AND deleted_at IS NULL',
      whereArgs: ['flight', b],
    );
    expect(forA.length, 1);
    expect(forB.length, 0);
  });

  test('the same file linked to a flight and a trip shows in both', () async {
    final tripId = await seedTrip('Uzbek');
    final flightId = await seedFlight(tripId);
    await seedAttachment(linkedType: 'flight', linkedId: flightId);
    await seedAttachment(linkedType: 'trip', linkedId: tripId);

    expect(
      await h.queryAll('app_files', where: 'linked_type = ? AND linked_id = ?', whereArgs: ['flight', flightId]),
      hasLength(1),
    );
    expect(
      await h.queryAll('app_files', where: 'linked_type = ? AND linked_id = ?', whereArgs: ['trip', tripId]),
      hasLength(1),
    );
  });

  test('soft-deleted attachments are hidden but the row is kept', () async {
    final tripId = await seedTrip('Uzbek');
    final flightId = await seedFlight(tripId);
    final id = await seedAttachment(linkedType: 'flight', linkedId: flightId, deleted: true);

    final visible = await h.queryAll(
      'app_files',
      where: 'linked_type = ? AND linked_id = ? AND deleted_at IS NULL',
      whereArgs: ['flight', flightId],
    );
    expect(visible, isEmpty);

    // Row survives so a restore cannot resurrect a deleted confirmation.
    final row = await h.queryOne('app_files', where: 'id = ?', whereArgs: [id]);
    expect(row, isNotNull);
    expect(row!['deleted_at'], isNotNull);
  });

  test('app_files is excluded from sync', () {
    // Its file_path is device-local, so syncing the metadata would create
    // broken entries on any other device.
    expect(DatabaseHelper.syncTables.contains('app_files'), isFalse);
    expect(DatabaseHelper.excludedFromSync.contains('app_files'), isTrue);
  });

  test('everything else still syncs', () {
    for (final t in ['trips', 'hotels', 'flights', 'expenses', 'passports', 'visas']) {
      expect(DatabaseHelper.syncTables.contains(t), isTrue, reason: '$t must still sync');
    }
  });

  test('attachments carry their size and mime for the UI', () async {
    final tripId = await seedTrip('Uzbek');
    final flightId = await seedFlight(tripId);
    await seedAttachment(
      linkedType: 'flight',
      linkedId: flightId,
      name: 'boarding-pass.png',
      mime: 'image/png',
      size: 512 * 1024,
    );

    final row = (await h.queryAll('app_files')).single;
    expect(row['mime_type'], 'image/png');
    expect(row['type'], 'image');
    expect(row['file_size'], 512 * 1024);
    expect(row['category'], 'confirmation');
  });

  test('attachment service sizes are human readable', () {
    expect(humanSize(512), '512 B');
    expect(humanSize(2048), '2 KB');
    expect(humanSize(5 * 1024 * 1024), '5.0 MB');
  });
}