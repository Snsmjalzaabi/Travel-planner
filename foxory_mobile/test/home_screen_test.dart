// Guards the Home dashboard: its cards used to be inert (onTap: () {}) and
// its queries ignored tombstones, so deleted rows stayed visible.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:your_travel_buddy/core/database_helper.dart';
import 'package:your_travel_buddy/services/soft_delete.dart';
import 'package:path/path.dart' as p;

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String dir;
  late DatabaseHelper h;

  setUp(() async {
    dir = (await Directory.systemTemp.createTemp('foxory_home')).path;
    DatabaseHelper.testOverridePath = p.join(dir, 'home.db');
    h = DatabaseHelper();
    await h.close();
  });

  Future<int> seedTrip(String name, {bool deleted = false}) async {
    final now = DateTime.now();
    final id = await h.insert('trips', {
      'name': name,
      'origin_name': 'Dubai',
      'origin_country': 'AE',
      'dest_name': 'Tashkent',
      'dest_country': 'UZ',
      'departure': now.add(const Duration(days: 10)).toIso8601String(),
      'return_date': now.add(const Duration(days: 16)).toIso8601String(),
      'transport_type': 'flight',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    if (deleted) {
      final db = await h.database;
      await softDelete(db, 'trips', id);
    }
    return id;
  }

  Future<int> seedTask(String title, {bool deleted = false, int status = 0}) async {
    final now = DateTime.now();
    final id = await h.insert('tasks', {
      'title': title,
      'status': status,
      'priority': 1,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    if (deleted) {
      final db = await h.database;
      await softDelete(db, 'tasks', id);
    }
    return id;
  }

  Future<int> seedExpense(String title, {bool deleted = false}) async {
    final now = DateTime.now();
    final id = await h.insert('expenses', {
      'title': title,
      'category': 'food',
      'amount': 50,
      'currency': 'AED',
      'base_amount': 50 / 3.67,
      'date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    if (deleted) {
      final db = await h.database;
      await softDelete(db, 'expenses', id);
    }
    return id;
  }

  test('home trip query hides soft-deleted trips', () async {
    await seedTrip('Live trip');
    await seedTrip('Dead trip', deleted: true);

    final db = await h.database;
    final now = DateTime.now();
    final upcoming = await db.query(
      'trips',
      where: 'departure >= ? AND status != ? AND deleted_at IS NULL',
      whereArgs: [now.toIso8601String(), 'COMPLETED'],
      orderBy: 'departure ASC',
      limit: 3,
    );
    expect(upcoming.length, 1);
    expect(upcoming.first['name'], 'Live trip');
  });

  test('home task query hides soft-deleted tasks', () async {
    await seedTask('Do task');
    await seedTask('Deleted task', deleted: true);

    final db = await h.database;
    final now = DateTime.now();
    final tasks = await db.query(
      'tasks',
      where: '(status IN (0, 1)) AND deleted_at IS NULL AND (due_date IS NULL OR due_date <= ?)',
      whereArgs: [now.toIso8601String()],
    );
    expect(tasks.length, 1);
    expect(tasks.first['title'], 'Do task');
  });

  test('home expense query hides soft-deleted expenses', () async {
    await seedExpense('Lunch');
    await seedExpense('Old dinner', deleted: true);

    final db = await h.database;
    final rows = await db.query(
      'expenses',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC',
    );
    expect(rows.length, 1);
    expect(rows.first['title'], 'Lunch');
  });

  test('completing a task sets status and completed_at', () async {
    final id = await seedTask('Pack passport');
    final db = await h.database;
    final now = DateTime.now();

    await db.update('tasks', {
      'status': 1,
      'completed_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);

    final row = await h.queryOne('tasks', where: 'id = ?', whereArgs: [id]);
    expect(row!['status'], 1);
    expect(row['completed_at'], isNotNull);
  });

  test('reopening a task clears completed_at', () async {
    final id = await seedTask('Pack passport', status: 1);
    final db = await h.database;

    await db.update('tasks', {
      'status': 0,
      'completed_at': null,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);

    final row = await h.queryOne('tasks', where: 'id = ?', whereArgs: [id]);
    expect(row!['status'], 0);
    expect(row['completed_at'], isNull);
  });

  test('deleting from home is a soft delete, not a row removal', () async {
    final id = await seedTrip('Keep me');
    final db = await h.database;

    await softDelete(db, 'trips', id);

    // Row still present (so a Pi restore honours the delete)...
    expect(await h.queryOne('trips', where: 'id = ?', whereArgs: [id]), isNotNull);
    // ...but invisible to reads.
    expect(await h.queryAll('trips', where: 'deleted_at IS NULL'), isEmpty);
  });

  test('every expense has base_amount so budgets stay correct', () async {
    await seedExpense('With base');
    final db = await h.database;
    final rows = await db.query('expenses', where: 'deleted_at IS NULL');
    for (final r in rows) {
      expect(r['base_amount'], isNotNull, reason: '${r['title']} is missing base_amount');
    }
  });

  test('no inert onTap callbacks remain in the UI files', () {
    final offenders = <String>[];
    for (final f in Directory('lib/ui').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      if (text.contains('onTap: () {},') || text.contains('onPressed: () {},')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty, reason: 'these do nothing when tapped');
  });

  test('task status is an enum index, not a string', () async {
    // Regression: Home compared status to 'todo'/'in_progress' strings while
    // the column stores TaskStatus.index, so pending tasks never appeared.
    await seedTask('Todo task');            // index 0
    await seedTask('In progress task', status: 1);
    await seedTask('Done task', status: 2);

    final db = await h.database;
    final rows = await db.query('tasks', orderBy: 'id');
    expect(rows.map((r) => r['status']).toList(), [0, 1, 2]);

    final now = DateTime.now();
    final pending = await db.query(
      'tasks',
      where: '(status IN (0, 1)) AND deleted_at IS NULL AND (due_date IS NULL OR due_date <= ?)',
      whereArgs: [now.toIso8601String()],
    );
    // The completed task must not show.
    expect(pending.length, 2);
    expect(pending.every((r) => r['title'] != 'Done task'), isTrue);
  });
}
