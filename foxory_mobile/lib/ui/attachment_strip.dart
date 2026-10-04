import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/attachment_service.dart';
import '../services/confirmation_parser.dart';

/// Attachments row with an upload button, for any linked entity.
///
/// Shown on flights, hotels and trips so a booking confirmation is one tap
/// away when you need it at a check-in desk.
class AttachmentStrip extends StatefulWidget {
  /// 'flight', 'hotel', 'trip', ...
  final String linkedType;
  final int linkedId;
  final String? title;

  const AttachmentStrip({
    super.key,
    required this.linkedType,
    required this.linkedId,
    this.title,
  });

  @override
  State<AttachmentStrip> createState() => _AttachmentStripState();
}

class _AttachmentStripState extends State<AttachmentStrip> {
  final _service = AttachmentService();
  List<Attachment> _items = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _service.listFor(widget.linkedType, widget.linkedId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _upload(AttachmentSource source) async {
    setState(() => _busy = true);
    try {
      Attachment? saved;
      switch (source) {
        case AttachmentSource.camera:
          saved = await _service.captureFromCamera(
              linkedType: widget.linkedType, linkedId: widget.linkedId);
        case AttachmentSource.gallery:
          saved = await _service.pickFromGallery(
              linkedType: widget.linkedType, linkedId: widget.linkedId);
        case AttachmentSource.file:
          saved = await _service.pickDocument(
              linkedType: widget.linkedType, linkedId: widget.linkedId);
      }
      if (!mounted || saved == null) return;
      final attachment = saved;
      setState(() {
        _items = [attachment, ..._items];
      });
      if (attachment.mimeType.contains('pdf')) {
        await _offerExtraction(attachment);
      }
    } on AttachmentTooLarge catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Too large (${humanSize(e.bytes)}). Maximum is 15 MB.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Add confirmation', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Saved on this device so it works offline.', style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              subtitle: const Text('Photograph a printed or displayed confirmation'),
              onTap: () {
                Navigator.pop(ctx);
                _upload(AttachmentSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a photo'),
              subtitle: const Text('Pick from your gallery, e.g. a screenshot of the email'),
              onTap: () {
                Navigator.pop(ctx);
                _upload(AttachmentSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a PDF or file'),
              subtitle: const Text('The emailed booking confirmation'),
              onTap: () {
                Navigator.pop(ctx);
                _upload(AttachmentSource.file);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Reads a freshly attached PDF and shows what it found for review.
  ///
  /// Deliberately a separate, explicit step: the parser is heuristic, and a
  /// wrong booking reference is worse than a missing one.
  Future<void> _offerExtraction(Attachment attachment) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Reading confirmation...'),
        duration: Duration(seconds: 3),
      ),
    );

    final extracted = await extractFromPdf(attachment);
    if (!mounted) return;

    if (extracted.scanned) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That PDF is a scan or image, so there is no text to read.'),
        ),
      );
      return;
    }
    if (!extracted.foundAnything) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not find booking details in that PDF.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => _ExtractionDialog(extracted: extracted, fileName: attachment.name),
    );
  }

  Future<void> _confirmDelete(Attachment a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete attachment?'),
        content: const Text('The file will be removed from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(a);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attachment, size: 15, color: cs.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 6),
            Text(
              widget.title ?? 'Confirmations',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(width: 6),
            if (_items.isNotEmpty)
              Text('${_items.length}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
            const Spacer(),
            _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : InkWell(
                    onTap: _openSheet,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.upload_file, size: 14, color: cs.primary),
                          const SizedBox(width: 5),
                          Text('Upload', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
        if (_items.isEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'No confirmation saved yet.',
            style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45)),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ..._items.map(_chip),
        ],
      ],
    );
  }

  Widget _chip(Attachment a) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            _thumb(a),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    a.name.length > 40 ? '${a.name.substring(0, 40)}...' : a.name,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${a.sizeLabel.isEmpty ? '' : '${a.sizeLabel} • '}${DateFormat('MMM d, HH:mm').format(a.createdAt)}',
                    style: GoogleFonts.inter(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: () => _confirmDelete(a),
              visualDensity: VisualDensity.compact,
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(Attachment a) {
    final cs = Theme.of(context).colorScheme;
    if (a.isImage && File(a.filePath).existsSync()) {
      return Image.file(
        File(a.filePath),
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fileIcon(cs),
      );
    }
    return _fileIcon(cs);
  }

  Widget _fileIcon(ColorScheme cs) {
    return Container(
      width: 46,
      height: 46,
      color: cs.onSurface.withValues(alpha: 0.07),
      child: Icon(
        Icons.description,
        size: 20,
        color: cs.onSurface.withValues(alpha: 0.55),
      ),
    );
  }
}

/// Where an attachment came from.
enum AttachmentSource { camera, gallery, file }

/// Shows what was read out of a confirmation so the user can check it.
/// Nothing is applied automatically - a wrong booking reference would be
/// worse than none, so this is read-only information to compare against.
class _ExtractionDialog extends StatelessWidget {
  final ExtractedConfirmation extracted;
  final String fileName;

  const _ExtractionDialog({required this.extracted, required this.fileName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Confirmation details found'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fileName, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 12),
            ...extracted.summary.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(line, style: GoogleFonts.inter(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check these against the PDF before using them. Nothing has been saved to your trip.',
                      style: GoogleFonts.inter(fontSize: 11, height: 1.35, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
