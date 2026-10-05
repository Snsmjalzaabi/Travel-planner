import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../core/database_helper.dart';
import '../core/app_settings.dart';
import 'confirmation_parser.dart';
import 'tailscale_guard.dart';

/// One stored attachment, as held in the `app_files` table.
class Attachment {
  final int? id;
  final String name;
  final String mimeType;
  final String filePath;
  final int fileSize;
  final String? linkedType;
  final int? linkedId;
  final DateTime createdAt;

  const Attachment({
    this.id,
    required this.name,
    required this.mimeType,
    required this.filePath,
    this.fileSize = 0,
    this.linkedType,
    this.linkedId,
    required this.createdAt,
  });

  bool get isImage => mimeType.startsWith('image/');

  String get sizeLabel {
    if (fileSize <= 0) return '';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(0)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Attachment.fromMap(Map<String, dynamic> m) => Attachment(
        id: m['id'] as int?,
        name: m['name'] as String? ?? 'file',
        mimeType: m['mime_type'] as String? ?? 'application/octet-stream',
        filePath: m['file_path'] as String? ?? '',
        fileSize: (m['file_size'] as int?) ?? 0,
        linkedType: m['linked_type'] as String?,
        linkedId: m['linked_id'] as int?,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Stores booking confirmations (photos and PDFs) on the device and links them
/// to a flight, hotel, trip or anything else.
///
/// Picked files are copied into the app's own documents directory. A path from
/// the picker is only valid for the current session, so storing it directly
/// would leave the attachment broken after a restart.
class AttachmentService {
  static const _folder = 'attachments';
  // Effectively unlimited for real documents and phone photos. The bound
  // exists only to stop a pathological file exhausting memory.
  static const _maxBytes = 100 * 1024 * 1024;

  /// Take a photo of the confirmation.
  Future<Attachment?> captureFromCamera({String? linkedType, int? linkedId}) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 2000,
    );
    if (picked == null) return null;
    return _saveImage(picked, linkedType, linkedId);
  }

  /// Choose an existing photo from the gallery.
  Future<Attachment?> pickFromGallery({String? linkedType, int? linkedId}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    return _saveImage(picked, linkedType, linkedId);
  }

  /// Choose a PDF or other document - the usual format for an emailed
  /// booking confirmation.
  ///
  /// file_picker has no web implementation, so this is a no-op there rather
  /// than a crash; the photo paths still work on web.
  Future<Attachment?> pickDocument({String? linkedType, int? linkedId}) async {
    if (kIsWeb) return null;
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
      compressionQuality: 0,
    );
    final file = result;
    final path = file?.path;
    if (file == null || path == null) return null;
    return _saveDocument(path, file.name, linkedType, linkedId);
  }

  Future<Attachment?> _saveImage(XFile image, String? linkedType, int? linkedId) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > _maxBytes) {
      throw AttachmentTooLarge(bytes.length);
    }
    final ext = p.extension(image.path).isEmpty ? '.jpg' : p.extension(image.path);
    final name = 'confirmation_${DateTime.now().millisecondsSinceEpoch}$ext';
    return _write(bytes, name, 'image/${ext.replaceAll('.', '')}', linkedType, linkedId);
  }

  Future<Attachment?> _saveDocument(String path, String displayName, String? linkedType, int? linkedId) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final size = await file.length();
    if (size > _maxBytes) {
      throw AttachmentTooLarge(size);
    }
    final bytes = await file.readAsBytes();
    final ext = p.extension(path).isEmpty ? '.pdf' : p.extension(path);
    final name = '${p.basenameWithoutExtension(displayName)}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final mime = ext.toLowerCase() == '.pdf' ? 'application/pdf' : 'image/${ext.replaceAll('.', '')}';
    return _write(bytes, name, mime, linkedType, linkedId);
  }

  Future<Attachment?> _write(
    List<int> bytes,
    String fileName,
    String mime,
    String? linkedType,
    int? linkedId,
  ) async {
    final dir = await _attachmentsDir();
    final target = File(p.join(dir.path, fileName));
    await target.writeAsBytes(bytes, flush: true);

    final now = DateTime.now();
    // Use the shared connection; opening a second one risks a lock error.
    final db = await DatabaseHelper().database;
    final id = await db.insert('app_files', {
      'trip_id': null,
      'task_id': null,
      'note_id': null,
      'name': fileName,
      'type': mime.startsWith('image/') ? 'image' : 'document',
      'mime_type': mime,
      'file_path': target.path,
      'thumbnail_path': null,
      'file_size': bytes.length,
      'byte_count': bytes.length,
      'width': null,
      'height': null,
      'folder_id': null,
      'category': 'confirmation',
      'description': null,
      'tags': '',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'linked_type': linkedType,
      'linked_id': linkedId,
      'sync_enabled': 0,
      'sync_status': 0,
      'deleted_at': null,
    });

    return Attachment(
      id: id,
      name: fileName,
      mimeType: mime,
      filePath: target.path,
      fileSize: bytes.length,
      linkedType: linkedType,
      linkedId: linkedId,
      createdAt: now,
    );
  }

  Future<Directory> _attachmentsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, _folder));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// All attachments linked to a given entity.
  Future<List<Attachment>> listFor(String linkedType, int linkedId) async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'app_files',
      where: 'linked_type = ? AND linked_id = ? AND deleted_at IS NULL',
      whereArgs: [linkedType, linkedId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  /// Every stored attachment, newest first.
  Future<List<Attachment>> listAll() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query(
      'app_files',
      where: 'deleted_at IS NULL',
      orderBy: 'created_at DESC',
    );
    return rows.map(Attachment.fromMap).toList();
  }

  /// Removes the row and the file from disk.
  Future<void> delete(Attachment attachment) async {
    if (attachment.id != null) {
      final db = await DatabaseHelper().database;
      await db.update(
        'app_files',
        {'deleted_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [attachment.id],
      );
    }

    final file = File(attachment.filePath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // The row is already marked deleted; a leftover file is harmless.
      }
    }
  }

  /// True when the file is still on disk (a restored backup may not have it).
  Future<bool> exists(Attachment attachment) => File(attachment.filePath).exists();
}

class AttachmentTooLarge implements Exception {
  final int bytes;
  AttachmentTooLarge(this.bytes);

  @override
  String toString() => 'AttachmentTooLarge';
}

String humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Sends a PDF to the Pi's extraction endpoint and parses the text it returns.
///
/// The Pi already runs the sync server and has poppler's pdftotext installed,
/// so this reuses that rather than pulling a PDF engine onto the phone.
/// Scanned images and screenshots return no text layer - those need OCR,
/// which is not wired up, so we say so instead of guessing.
Future<ExtractedConfirmation> extractFromPdf(Attachment attachment) async {
  final name = attachment.name.toLowerCase();
  final isPdf = attachment.mimeType.contains('pdf') || name.endsWith('.pdf');
  final isImage = attachment.mimeType.startsWith('image/') ||
      const ['.png', '.jpg', '.jpeg', '.webp', '.heic'].any(name.endsWith);
  if (!isPdf && !isImage) return const ExtractedConfirmation();

  final file = File(attachment.filePath);
  if (!await file.exists()) return const ExtractedConfirmation();

  final settings = AppSettings();
  await settings.init();
  if (settings.piAddress.trim().isEmpty) return const ExtractedConfirmation();

  // Confirmations are personal documents. They only leave the phone over
  // Tailscale, same as the rest of the trip data - never over the LAN.
  final gate = await const TailscaleGuard().probe(settings.piAddress, settings.piPort);
  if (!gate.allowed) return const ExtractedConfirmation();

  final bytes = await file.readAsBytes();
  final uri = Uri.parse('http://${settings.piAddress}:${settings.piPort}/sync/extract');
  final contentType = isPdf
      ? 'application/pdf'
      : attachment.mimeType.startsWith('image/')
          ? attachment.mimeType
          : 'image/jpeg';

  try {
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': contentType,
            'X-Device-ID': settings.deviceId,
            if (settings.syncPassword.isNotEmpty) 'X-Sync-Password': settings.syncPassword,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 40));

    if (response.statusCode != 200) {
      return const ExtractedConfirmation();
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final scanned = decoded['scanned'] == true;
    final method = decoded['method'] as String?;
    final text = (decoded['text'] as String?) ?? '';
    final parsed = const ConfirmationParser().parse(text, scanned: scanned);
    // "ocr-timeout" means the Pi stopped reading early; say so rather than
    // letting a partial reference look authoritative.
    if (method != 'ocr-timeout') return parsed;
    return ExtractedConfirmation(
      reference: parsed.reference,
      flightNumber: parsed.flightNumber,
      airline: parsed.airline,
      from: parsed.from,
      to: parsed.to,
      dates: parsed.dates,
      seat: parsed.seat,
      hotelName: parsed.hotelName,
      total: parsed.total,
      incomplete: true,
    );
  } on http.ClientException {
    // Pi unreachable - not worth blocking the upload.
    return const ExtractedConfirmation();
  } catch (_) {
    // Pi unreachable, or extraction failed. Not worth blocking the upload.
    return const ExtractedConfirmation();
  }
}
