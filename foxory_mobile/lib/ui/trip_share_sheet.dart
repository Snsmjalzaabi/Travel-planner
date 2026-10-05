import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';
import '../services/trip_share_service.dart';

/// Lets Sultan choose what goes into the brief, then sends it.
///
/// Built as a sheet rather than a straight "share" because the point of this
/// app is that he decides what friends see - a shared budget breakdown is not
/// the same thing as a shared expense list, and he may want only one of them.
Future<void> showTripShareSheet(BuildContext context, Trip trip) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _TripShareSheet(trip: trip),
  );
}

class _TripShareSheet extends StatefulWidget {
  final Trip trip;
  const _TripShareSheet({required this.trip});

  @override
  State<_TripShareSheet> createState() => _TripShareSheetState();
}

class _TripShareSheetState extends State<_TripShareSheet> {
  bool _includeBudget = true;
  bool _includeExpenses = true;
  bool _busy = false;
  String? _error;

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await const TripShareService().share(
        widget.trip,
        includeBudget: _includeBudget,
        includeExpenses: _includeExpenses,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not build the PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share "${widget.trip.name}"',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Creates a PDF on this phone, then hands it to whatever you want to send with.',
              style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),

            _toggle(
              'Budget breakdown',
              'What you set aside per category, what is spent, and what is left.',
              _includeBudget,
              (v) => setState(() => _includeBudget = v),
            ),
            _toggle(
              'Expense list',
              'Every expense with its date, category and amount.',
              _includeExpenses,
              (v) => setState(() => _includeExpenses = v),
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 14, color: cs.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Flights, hotels, day-by-day plan, packing list and booking references are always included. '
                      'The PDF is built on the phone - nothing is uploaded to send it.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.35,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: GoogleFonts.inter(fontSize: 12, color: Colors.red)),
            ],

            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: _busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 17),
                    label: Text(_busy ? 'Building...' : 'Create & send'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: value ? cs.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: value ? cs.primary.withValues(alpha: 0.35) : cs.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}