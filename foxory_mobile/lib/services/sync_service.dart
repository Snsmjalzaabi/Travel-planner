import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/app_settings.dart';

class SyncService {
  final AppSettings settings;
  final String baseUrl;

  SyncService(this.settings)
      : baseUrl = 'http://${settings.piAddress}:${settings.piPort}';

  // Upload data to Pi
  Future<SyncResult> upload({
    required String module,
    required List<Map<String, dynamic>> records,
    String? deviceId,
  }) async {
    final devId = deviceId ?? settings.deviceId;
    if (devId.isEmpty) {
      return SyncResult(success: false, error: 'No device ID');
    }
    if (settings.piAddress.isEmpty) {
      return SyncResult(success: false, error: 'Pi address not configured');
    }

    try {
      final client = http.Client();
      client.hashCode; // keep reference
      final response = await http.post(
        Uri.parse('$baseUrl/sync/upload'),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-ID': devId,
          if (settings.syncPassword.isNotEmpty)
            'X-Sync-Password': settings.syncPassword,
        },
        body: jsonEncode({
          'module': module,
          'device_id': devId,
          'records': records,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncResult(
          success: true,
          serverId: data['server_id'] as String?,
          serverTimestamp: data['server_timestamp'] as String?,
        );
      } else {
        return SyncResult(
          success: false,
          error: 'Server returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return SyncResult(success: false, error: 'Sync failed: $e');
    }
  }

  // Download data from Pi
  Future<SyncResult> download({
    required String module,
    required DateTime since,
    String? deviceId,
  }) async {
    final devId = deviceId ?? settings.deviceId;
    if (devId.isEmpty) {
      return SyncResult(success: false, error: 'No device ID');
    }
    if (settings.piAddress.isEmpty) {
      return SyncResult(success: false, error: 'Pi address not configured');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sync/download?module=$module&since=${since.toIso8601String()}&device_id=$devId'),
        headers: {
          'X-Device-ID': devId,
          if (settings.syncPassword.isNotEmpty)
            'X-Sync-Password': settings.syncPassword,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final records = (data['records'] as List<dynamic>?)
                ?.map((r) => r as Map<String, dynamic>)
                .toList() ??
            [];
        final serverTimestamp = data['server_timestamp'] as String?;
        return SyncResult(
          success: true,
          records: records,
          serverTimestamp: serverTimestamp,
        );
      } else {
        return SyncResult(
          success: false,
          error: 'Server returned ${response.statusCode}',
        );
      }
    } catch (e) {
      return SyncResult(success: false, error: 'Download failed: $e');
    }
  }

  // Upload a file
  Future<SyncResult> uploadFile({
    required String module,
    required int recordId,
    required String filePath,
    required String fileName,
    String? deviceId,
  }) async {
    final devId = deviceId ?? settings.deviceId;
    if (devId.isEmpty || settings.piAddress.isEmpty) {
      return SyncResult(success: false, error: 'Not configured');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/sync/upload-file'),
      );
      request.headers['X-Device-ID'] = devId;
      if (settings.syncPassword.isNotEmpty) {
        request.headers['X-Sync-Password'] = settings.syncPassword;
      }
      request.fields['module'] = module;
      request.fields['device_id'] = devId;
      request.fields['record_id'] = recordId.toString();
      request.fields['file_name'] = fileName;

      final file = await http.MultipartFile.fromPath(
        'file',
        filePath,
        filename: fileName,
      );
      request.files.add(file);

      final response = await request.send().then((stream) =>
          http.Response.fromStream(stream));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return SyncResult(
          success: true,
          serverId: data['server_path'] as String?,
        );
      } else {
        return SyncResult(
          success: false,
          error: 'Upload failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      return SyncResult(success: false, error: 'File upload failed: $e');
    }
  }
}

class SyncResult {
  final bool success;
  final String? error;
  final String? serverId;
  final String? serverTimestamp;
  final List<Map<String, dynamic>>? records;

  SyncResult({
    required this.success,
    this.error,
    this.serverId,
    this.serverTimestamp,
    this.records,
  });
}
