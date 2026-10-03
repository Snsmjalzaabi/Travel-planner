// Guards the dead-code sweep: asserts nothing references the deleted services
// or models, and that removed tables no longer have DDL.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:foxory_mobile/core/database_helper.dart';
import 'package:path/path.dart' as p;

void main() {
  test('deleted service and model files are really gone', () {
    const gone = [
      'lib/services/sync_service.dart',
      'lib/services/export_import_service.dart',
      'lib/services/file_service.dart',
      'lib/models/app_settings_model.dart',
    ];
    for (final rel in gone) {
      expect(File(rel).existsSync(), isFalse, reason: '$rel should have been deleted');
    }
  });

  test('no lib file imports the deleted services', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);
    final offenders = <String>[];
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final dead in [
        'sync_service.dart',
        'export_import_service.dart',
        'file_service.dart',
        'app_settings_model.dart',
      ]) {
        if (text.contains("'$dead'")) {
          offenders.add('${f.path} imports $dead');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('no lib file references the deleted class names', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final sym in ['ExportImportService', 'TripData', 'AllTripsData', 'FileService']) {
        if (text.contains(sym)) offenders.add('${f.path} uses $sym');
      }
    }
    expect(offenders, isEmpty);
  });

  test('removed tables no longer have DDL, and the kept ones do', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = (await Directory.systemTemp.createTemp('foxory_ddl')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'd.db');
    final h = DatabaseHelper();
    await h.close();

    final db = await h.database;
    final names = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => r['name'] as String)
        .toSet();

    // Removed for good - never written anywhere.
    expect(names.contains('task_projects'), isFalse);
    expect(names.contains('folders'), isFalse);
    expect(names.contains('app_settings'), isFalse);

    // Core tables must survive; dropping one would be data loss.
    for (final keep in ['trips', 'hotels', 'flights', 'expenses', 'passports', 'visas', 'sync_log', 'notes', 'tasks']) {
      expect(names.contains(keep), isTrue, reason: '$keep must still exist');
    }
  });

  test('every sync table carries the soft-delete column', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dir = (await Directory.systemTemp.createTemp('foxory_sd')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'sd.db');
    final h = DatabaseHelper();
    await h.close();
    final db = await h.database;

    for (final table in DatabaseHelper.syncTables) {
      final cols = (await db.rawQuery('PRAGMA table_info($table)'))
          .map((c) => c['name'] as String)
          .toSet();
      expect(cols.contains('deleted_at'), isTrue, reason: '$table needs deleted_at');
    }
  });
}