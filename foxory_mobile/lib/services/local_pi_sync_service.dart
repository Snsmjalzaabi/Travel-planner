import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/app_settings.dart';
import '../core/database_helper.dart';

/// Real, simple sync for personal Pi use.
///
/// Uploads all important local SQLite tables as JSON to a small HTTP
/// server running on the Pi. This is intentionally one-way for now:
/// phone/app -> Pi backup. It fixes the old UI issue where sync only
/// displayed a fake "started" message.
class LocalPiSyncService {
  static const _tables = [
    'trips',
    'hotels',
    'flights',
    'itinerary_days',
    'itinerary_activities',
    'expenses',
    'packing_items',
    'passports',
    'visas',
    'notes',
    'tasks',
    'app_files',
  ];

  final AppSettings settings;
  final DatabaseHelper dbHelper;

  LocalPiSyncService({required this.settings, required this.dbHelper});

  String get baseUrl => 'http://${settings.piAddress}:${settings.piPort}';

  Future<LocalSyncResult> uploadAll() async {
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
    for (final table in _tables) {
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

  const LocalSyncResult({
    required this.success,
    required this.message,
    this.recordCount = 0,
    this.syncedAt,
  });

  factory LocalSyncResult.failure(String message) {
    return LocalSyncResult(success: false, message: message);
  }
}
