// Merge semantics for restore. The important guarantee is that a row the user
// deleted is never resurrected, and that a stale backup cannot overwrite
// newer local data.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/app_settings.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:foxory_mobile/models/models.dart';
import 'package:foxory_mobile/services/local_pi_sync_service.dart';
import 'package:foxory_mobile/services/soft_delete.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;
  late DatabaseHelper h;
  late LocalPiSyncService svc;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_sync')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 's.db');
    h = DatabaseHelper();
    await h.close();
    svc = LocalPiSyncService(
      settings: AppSettings()..piAddress = '127.0.0.1',
      dbHelper: h,
    );
  });

  Future<int> seedTrip(String name, {String? updatedAt}) async {
    final now = DateTime.now();
    return h.insert('trips', {
      'name': name,
      'origin_name': 'Dubai',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': now.toIso8601String(),
      'return_date': now.add(const Duration(days: 3)).toIso8601String(),
      'transport_type': 'flight',
      'created_at': (updatedAt ?? now.toIso8601String()),
      'updated_at': (updatedAt ?? now.toIso8601String()),
    });
  }

  Map<String, dynamic> tripRow(int id, String name, {String? updatedAt, String? deletedAt}) => {
        'id': id,
        'name': name,
        'origin_name': 'Dubai',
        'origin_country': 'AE',
        'dest_name': 'Tashkent',
        'dest_country': 'UZ',
        'departure': DateTime(2026, 1, 1).toIso8601String(),
        'return_date': DateTime(2026, 1, 5).toIso8601String(),
        'transport_type': 'flight',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'updated_at': updatedAt ?? DateTime(2026, 1, 1).toIso8601String(),
        if (deletedAt != null) 'deleted_at': deletedAt,
      };

  Future<List<Trip>> names() async =>
      (await h.queryAll('trips', orderBy: 'id')).map(Trip.fromMap).toList();

  test('a row deleted locally is NOT resurrected by an older backup', () async {
    final id = await seedTrip('Doomed');
    final db = await h.database;
    await softDelete(db, 'trips', id);

    // Pi still has the row, live, because it synced before the delete.
    final backup = {
      'trips': [tripRow(id, 'Doomed', updatedAt: '2026-06-01T00:00:00')],
    };

    final result = await svc.restoreBackup(backup);
    expect(result.success, isTrue);

    final rows = await names();
    expect(rows.single.name, 'Doomed');
    final raw = await h.queryOne('trips', where: 'id = ?', whereArgs: [id]);
    expect(isTombstone(raw!), isTrue, reason: 'the tombstone must survive the restore');
  });

  test('a tombstone from the Pi deletes the local row', () async {
    final id = await seedTrip('Gone');
    final backup = {
      'trips': [tripRow(id, 'Gone', deletedAt: '2026-06-02T10:00:00')],
    };

    await svc.restoreBackup(backup);

    final raw = await h.queryOne('trips', where: 'id = ?', whereArgs: [id]);
    expect(raw, isNotNull, reason: 'row is kept as a tombstone, not dropped');
    expect(isTombstone(raw!), isTrue);
    // And it disappears from normal reads.
    expect(await h.queryAll('trips', where: 'deleted_at IS NULL'), isEmpty);
  });

  test('newer remote data wins over older local data', () async {
    final id = await seedTrip('Old name', updatedAt: '2026-01-01T00:00:00');
    final backup = {
      'trips': [tripRow(id, 'New name', updatedAt: '2026-06-01T00:00:00')],
    };

    await svc.restoreBackup(backup);
    expect((await names()).single.name, 'New name');
  });

  test('older remote data does NOT overwrite newer local data', () async {
    final id = await seedTrip('Current name', updatedAt: '2026-06-01T00:00:00');
    final backup = {
      'trips': [tripRow(id, 'Stale name', updatedAt: '2026-01-01T00:00:00')],
    };

    await svc.restoreBackup(backup);
    expect((await names()).single.name, 'Current name');
  });

  test('unknown rows are inserted', () async {
    final backup = {
      'trips': [tripRow(999, 'Restored trip', updatedAt: '2026-06-01T00:00:00')],
    };
    final result = await svc.restoreBackup(backup);
    expect(result.recordCount, 1);
    expect((await names()).single.name, 'Restored trip');
  });

  test('a row with no parseable timestamps keeps local data', () async {
    final id = await seedTrip('Good', updatedAt: '2026-06-01T00:00:00');
    final backup = {
      'trips': [
        {'id': id, 'name': 'Garbage', 'origin_name': 'X', 'origin_country': 'X', 'dest_name': 'Y', 'dest_country': 'Y', 'departure': '2026-01-01', 'return_date': '2026-01-02'},
      ],
    };
    await svc.restoreBackup(backup);
    expect((await names()).single.name, 'Good');
  });

  test('unknown columns in the backup are ignored, not fatal', () async {
    final backup = {
      'trips': [
        {
          ...tripRow(500, 'From future build', updatedAt: '2026-06-01T00:00:00'),
          'some_future_column': 'surprise',
        },
      ],
    };
    final result = await svc.restoreBackup(backup);
    expect(result.success, isTrue);
    expect((await names()).single.name, 'From future build');
  });

  test('replace wipes local rows that are absent from the backup', () async {
    await seedTrip('Local only');
    final backup = {
      'trips': [tripRow(7, 'From Pi', updatedAt: '2026-06-01T00:00:00')],
    };

    await svc.replaceFromBackup(backup);

    final rows = await names();
    expect(rows.length, 1);
    expect(rows.single.name, 'From Pi');
  });

  test('merge keeps local-only rows', () async {
    await seedTrip('Local only');
    final backup = {
      'trips': [tripRow(7, 'From Pi', updatedAt: '2026-06-01T00:00:00')],
    };

    await svc.restoreBackup(backup);

    final names_ = (await names()).map((t) => t.name).toList();
    expect(names_, containsAll(<String>['Local only', 'From Pi']));
  });

  test('restore writes a sync_log entry', () async {
    final backup = {
      'trips': [tripRow(11, 'Logged', updatedAt: '2026-06-01T00:00:00')],
    };
    await svc.restoreBackup(backup);

    final logs = await h.queryAll('sync_log', orderBy: 'id DESC');
    expect(logs, isNotEmpty);
    expect(logs.first['direction'], 'restore');
  });

  test('softDelete/softUndelete round-trip', () async {
    final id = await seedTrip('Toggle me');
    final db = await h.database;

    await softDelete(db, 'trips', id);
    expect(isTombstone((await h.queryOne('trips', where: 'id = ?', whereArgs: [id]))!), isTrue);

    await softUndelete(db, 'trips', id);
    expect(isTombstone((await h.queryOne('trips', where: 'id = ?', whereArgs: [id]))!), isFalse);
  });
}