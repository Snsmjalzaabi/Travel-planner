import 'package:sqflite/sqflite.dart';

class SyncLog {
  final int? id;
  final String deviceId;
  final String direction; // 'upload' or 'download'
  final String module;
  final String action; // 'create', 'update', 'delete', 'sync'
  final int recordId;
  final String tableName;
  final String? recordData;
  final String? error;
  final DateTime syncedAt;
  final int? serverResponseTime;
  final bool success;
  final int? retryCount;
  final DateTime? lastRetry;
  final String? syncBatchId;

  SyncLog({
    this.id,
    required this.deviceId,
    required this.direction,
    required this.module,
    required this.action,
    required this.recordId,
    required this.tableName,
    this.recordData,
    this.error,
    required this.syncedAt,
    this.serverResponseTime,
    this.success = true,
    this.retryCount,
    this.lastRetry,
    this.syncBatchId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'device_id': deviceId,
        'direction': direction,
        'module': module,
        'action': action,
        'record_id': recordId,
        'table_name': tableName,
        'record_data': recordData,
        'error': error,
        'synced_at': syncedAt.toIso8601String(),
        'server_response_time': serverResponseTime,
        'success': success ? 1 : 0,
        'retry_count': retryCount,
        'last_retry': lastRetry?.toIso8601String(),
        'sync_batch_id': syncBatchId,
      };

  factory SyncLog.fromMap(Map<String, dynamic> map) => SyncLog(
        id: map['id'] as int?,
        deviceId: map['device_id'] as String,
        direction: map['direction'] as String,
        module: map['module'] as String,
        action: map['action'] as String,
        recordId: map['record_id'] as int,
        tableName: map['table_name'] as String,
        recordData: map['record_data'] as String?,
        error: map['error'] as String?,
        syncedAt: DateTime.parse(map['synced_at'] as String),
        serverResponseTime: map['server_response_time'] as int?,
        success: (map['success'] as int? ?? 1) == 1,
        retryCount: map['retry_count'] as int?,
        lastRetry: map['last_retry'] != null
            ? DateTime.parse(map['last_retry'] as String)
            : null,
        syncBatchId: map['sync_batch_id'] as String?,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "sync_log" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "device_id" TEXT NOT NULL,
      "direction" TEXT NOT NULL,
      "module" TEXT NOT NULL,
      "action" TEXT NOT NULL,
      "record_id" INTEGER NOT NULL,
      "table_name" TEXT NOT NULL,
      "record_data" TEXT,
      "error" TEXT,
      "synced_at" TEXT NOT NULL,
      "server_response_time" INTEGER,
      "success" INTEGER DEFAULT 1,
      "retry_count" INTEGER,
      "last_retry" TEXT,
      "sync_batch_id" TEXT
    )
  ''';

  SyncLog copyWith({
    int? id,
    String? deviceId,
    String? direction,
    String? module,
    String? action,
    int? recordId,
    String? tableName,
    String? recordData,
    String? error,
    DateTime? syncedAt,
    int? serverResponseTime,
    bool? success,
    int? retryCount,
    DateTime? lastRetry,
    String? syncBatchId,
  }) {
    return SyncLog(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      direction: direction ?? this.direction,
      module: module ?? this.module,
      action: action ?? this.action,
      recordId: recordId ?? this.recordId,
      tableName: tableName ?? this.tableName,
      recordData: recordData ?? this.recordData,
      error: error ?? this.error,
      syncedAt: syncedAt ?? this.syncedAt,
      serverResponseTime: serverResponseTime ?? this.serverResponseTime,
      success: success ?? this.success,
      retryCount: retryCount ?? this.retryCount,
      lastRetry: lastRetry ?? this.lastRetry,
      syncBatchId: syncBatchId ?? this.syncBatchId,
    );
  }
}
