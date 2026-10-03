/// Soft-delete helpers shared by sync and the delete paths.
///
/// Sync needs to tell three states apart:
///   - the row was never here      -> safe to insert
///   - the row exists and is live  -> merge by timestamp
///   - the row is tombstoned       -> deleted on purpose, never resurrect
///
/// Without the tombstone, restoring a backup would silently bring back
/// records the user deliberately deleted.
library;

import 'package:sqflite/sqflite.dart';

const String softDeleteColumn = 'deleted_at';

/// True when this row has been deleted (or arrived from a device where it was).
bool isTombstone(Map<String, dynamic> row) {
  final v = row[softDeleteColumn];
  if (v == null) return false;
  if (v is String) return v.trim().isNotEmpty;
  return true;
}

/// Marks a row deleted without removing it.
Future<void> softDelete(DatabaseExecutor db, String table, int id, {DateTime? at}) async {
  await db.update(
    table,
    {softDeleteColumn: (at ?? DateTime.now()).toIso8601String()},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// Restores a tombstoned row.
Future<void> softUndelete(DatabaseExecutor db, String table, int id) async {
  await db.update(table, {softDeleteColumn: null}, where: 'id = ?', whereArgs: [id]);
}

/// True when [remote] should win over [local].
///
/// Tombstones are handled by the caller. For live rows the later
/// `updated_at` wins, falling back to `created_at`, and finally to
/// "keep local" when neither carries a parseable timestamp — so a malformed
/// row can never wipe a good one.
bool remoteIsNewer(Map<String, dynamic> remote, Map<String, dynamic> local) {
  final r = _stamp(remote);
  final l = _stamp(local);
  if (r == null) return false;
  if (l == null) return true;
  return r.isAfter(l);
}

DateTime? _stamp(Map<String, dynamic> row) {
  for (final key in const ['updated_at', 'created_at']) {
    final raw = row[key];
    if (raw is! String || raw.trim().isEmpty) continue;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return null;
}