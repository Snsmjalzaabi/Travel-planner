import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../core/app_settings.dart';
import 'tailscale_guard.dart';
import '../core/database_helper.dart';
import 'soft_delete.dart';

/// Real, simple sync for personal Pi use.
///
/// Uploads all important local SQLite tables as JSON to a small HTTP
/// server running on the Pi. This is intentionally one-way for now:
/// phone/app -> Pi backup. It fixes the old UI issue where sync only
/// displayed a fake "started" message.
class LocalPiSyncService {
  final AppSettings settings;
  final DatabaseHelper dbHelper;

  LocalPiSyncService({required this.settings, required this.dbHelper});

  String get baseUrl => 'http://${settings.piAddress}:${settings.piPort}';

  /// Blocks any transfer unless the Pi is genuinely reachable over Tailscale.
  ///
  /// Every sync entry point calls this first. Trip data does not leave the
  /// phone over the local network, even though the Pi is reachable there.
  Future<TailscaleCheck> _gate() async {
    final check = await const TailscaleGuard().probe(settings.piAddress, settings.piPort);
    lastBlockedReason = check.allowed ? null : check.message;
    return check;
  }

  /// Set when a transfer was refused, so the UI can explain why.
  String? lastBlockedReason;

  Future<LocalSyncResult> uploadAll() async {
    final gate = await _gate();
    if (!gate.allowed) return LocalSyncResult.skipped(gate.message);
    if (settings.piAddress.trim().isEmpty) {
      return LocalSyncResult.failure('Pi IP address is empty.');
    }

    final db = await dbHelper.database;
    final payload = <String, dynamic>{
      'device_id': settings.deviceId,
      'sent_at': DateTime.now().toIso8601String(),
      'tables': <String, List<Map<String, dynamic>>>{},
    };

    var totalRecords = 0;
    final tablesPayload = payload['tables'] as Map<String, List<Map<String, dynamic>>>;
    for (final table in DatabaseHelper.syncTables) {
      // Include tombstoned rows so deletions propagate on restore.
      final rows = await db.query(table);
      tablesPayload[table] = rows;
      totalRecords += rows.length;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/sync/upload'),
            headers: {
              'Content-Type': 'application/json',
              'X-Device-ID': settings.deviceId,
              if (settings.syncPassword.isNotEmpty)
                'X-Sync-Password': settings.syncPassword,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final syncedAt = DateTime.now();
        await settings.setLastSyncAt(syncedAt);
        return LocalSyncResult(
          success: true,
          message: 'Synced $totalRecords records to Pi.',
          recordCount: totalRecords,
          syncedAt: syncedAt,
        );
      }

      return LocalSyncResult.failure(
        'Pi returned ${response.statusCode}: ${_shortBody(response.body)}',
      );
    } catch (e) {
      return LocalSyncResult.failure(
        'Could not reach Pi at $baseUrl. Make sure the Pi sync server is running and your phone is on the same Wi‑Fi.\n\n$e',
      );
    }
  }

  /// Fetches the Pi's latest backup for this device.
  Future<LocalSyncResult> downloadLatest() async {
    final gate = await _gate();
    if (!gate.allowed) return LocalSyncResult.skipped(gate.message);
    if (settings.piAddress.trim().isEmpty) {
      return LocalSyncResult.failure('Pi IP address is empty.');
    }
    try {
      final uri = Uri.parse('$baseUrl/sync/download')
          .replace(queryParameters: {'device_id': settings.deviceId});
      final response = await http.get(
        uri,
        headers: {
          'X-Device-ID': settings.deviceId,
          if (settings.syncPassword.isNotEmpty) 'X-Sync-Password': settings.syncPassword,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        return LocalSyncResult.failure(
          'No backup on the Pi yet for this device. Run Sync Now once first.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return LocalSyncResult.failure('Pi returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final tables = (decoded['tables'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as List).cast<Map<String, dynamic>>())) ??
          <String, List<Map<String, dynamic>>>{};

      return LocalSyncResult(
        success: true,
        message: 'Downloaded ${tables.values.fold<int>(0, (a, b) => a + b.length)} records from Pi.',
        backupTables: tables,
        backupTimestamp: decoded['sent_at'] as String?,
      );
    } catch (e) {
      return LocalSyncResult.failure('Could not reach Pi at $baseUrl.\n\n$e');
    }
  }

  /// Merges a downloaded backup into the local database.
  ///
  /// Rules, in order of precedence:
  ///  - a tombstone in either copy wins (the row stays deleted)
  ///  - otherwise the newer `updated_at`/`created_at` wins
  ///  - local-only rows are kept, never deleted
  Future<LocalSyncResult> restoreBackup(Map<String, List<Map<String, dynamic>>> backup) async {
    // Deliberately NOT gated: this merges data the phone already holds. Nothing
    // leaves the device, so the Tailscale rule does not apply here. The gate
    // belongs on the network calls (uploadAll, downloadLatest).
    final db = await dbHelper.database;
    final report = <String>[];
    var written = 0;
    var tombstones = 0;

    for (final table in DatabaseHelper.syncTables) {
      final incoming = backup[table];
      if (incoming == null) continue;

      for (final remote in incoming) {
        final row = Map<String, dynamic>.from(remote);

        // Local tombstone beats anything the Pi still has.
        final localRow = await _findLocal(db, table, row['id']);
        final localDeleted = localRow != null && isTombstone(localRow);

        if (isTombstone(row)) {
          tombstones++;
          if (localRow == null) {
            await _insertRaw(db, table, row);
          } else {
            await db.update(table, {'deleted_at': row['deleted_at']}, where: 'id = ?', whereArgs: [row['id']]);
          }
          continue;
        }

        if (localDeleted) continue; // never resurrect
        if (localRow == null) {
          await _insertRaw(db, table, row);
          written++;
          continue;
        }
        if (remoteIsNewer(row, localRow)) {
          await db.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
          written++;
        }
      }
      report.add('$table: ${incoming.length} from Pi');
    }

    await _log('restore', 'Pi', written, null);
    return LocalSyncResult(
      success: true,
      message: 'Restored $written updated records'
          '${tombstones > 0 ? ', kept $tombstones deletions' : ''}.',
      recordCount: written,
    );
  }

  /// Replaces everything local with the backup. Destructive by design.
  Future<LocalSyncResult> replaceFromBackup(Map<String, List<Map<String, dynamic>>> backup) async {
    final db = await dbHelper.database;
    var written = 0;
    for (final table in DatabaseHelper.syncTables) {
      final incoming = backup[table];
      if (incoming == null) continue;
      await db.delete(table);
      for (final row in incoming) {
        await _insertRaw(db, table, Map<String, dynamic>.from(row));
        written++;
      }
    }
    await _log('restore', 'Pi (replace)', written, null);
    return LocalSyncResult(success: true, message: 'Replaced local data with $written records from Pi.', recordCount: written);
  }

  /// Raw insert that tolerates columns the current build does not know about,
  /// so an older/newer Pi backup can never crash a restore.
  Future<void> _insertRaw(Database db, String table, Map<String, dynamic> row) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final allowed = columns.map((c) => c['name'] as String).toSet();
    final filtered = <String, dynamic>{};
    row.forEach((k, v) {
      if (allowed.contains(k)) filtered[k] = v;
    });
    await db.insert(table, filtered, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> _findLocal(Database db, String table, Object? id) async {
    if (id == null) return null;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _log(String direction, String module, int records, String? error) async {
    final db = await dbHelper.database;
    await db.insert('sync_log', {
      'device_id': settings.deviceId,
      'direction': direction,
      'module': module,
      'action': direction == 'upload' ? 'backup' : 'restore',
      'record_id': 0,
      'table_name': module,
      'record_data': null,
      'error': error,
      'synced_at': DateTime.now().toIso8601String(),
      'server_response_time': null,
      'success': error == null ? 1 : 0,
      'retry_count': 0,
      'last_retry': null,
      'sync_batch_id': null,
    });
  }

  String _shortBody(String body) {
    final clean = body.trim().replaceAll('\n', ' ');
    if (clean.length <= 160) return clean;
    return '${clean.substring(0, 160)}...';
  }
}

class LocalSyncResult {
  final bool success;
  final String message;
  final int recordCount;
  final DateTime? syncedAt;

  /// Populated by [LocalPiSyncService.downloadLatest].
  final Map<String, List<Map<String, dynamic>>>? backupTables;
  final String? backupTimestamp;

  const LocalSyncResult({
    required this.success,
    required this.message,
    this.recordCount = 0,
    this.syncedAt,
    this.backupTables,
    this.backupTimestamp,
  });

  factory LocalSyncResult.failure(String message) {
    return LocalSyncResult(success: false, message: message);
  }

  /// Not an error - the transfer was deliberately declined because data is
  /// only allowed to move over Tailscale. Distinct from [failure] so the UI
  /// can say "held on the phone" rather than "something went wrong".
  factory LocalSyncResult.skipped(String message) {
    return LocalSyncResult(success: false, message: message, recordCount: 0);
  }
}
