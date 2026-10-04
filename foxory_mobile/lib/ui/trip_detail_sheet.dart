import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/recommendation_service.dart';
import 'trip_budget_panel.dart';
import 'budget_breakdown_screen.dart';
import 'attachment_strip.dart';
import '../core/database_helper.dart';
import 'create_trip_dialog.dart';

/// Shared trip detail sheet, used by the Trips tab and the Home dashboard
/// so both show the same information and the same actions.
void showTripDetailSheet(
  BuildContext context,
  Trip trip, {
  required List<Expense> expenses,
  required VoidCallback onChanged,
  VoidCallback? onEdit,
}) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateRange = '${DateFormat('MMM d').format(trip.departure)} – ${DateFormat('MMM d, y').format(trip.returnDate)}';
    final budget = trip.totalBudget > 0
        ? NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget)
        : 'No budget set';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${trip.originName} → ${trip.destName}',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.35,
                          color: colorScheme.onSurface.withValues(alpha: 0.68),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusChip(trip.status, colorScheme),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  _tripDetailRow(context, Icons.calendar_month, 'Dates', dateRange),
                  const Divider(height: 20),
                  _tripDetailRow(context, Icons.hotel_outlined, 'Length', trip.nights <= 0 ? 'Day trip' : '${trip.nights} nights'),
                  const Divider(height: 20),
                  _tripDetailRow(context, Icons.people_outline, 'Travelers', '${trip.travelers}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  _tripDetailRow(context, Icons.directions_transit_outlined, 'Transport', trip.transportLabel),
                  const Divider(height: 20),
                  _tripDetailRow(context, Icons.account_balance_wallet_outlined, 'Budget', budget),
                  if (trip.originCountry != 'Unknown' || trip.destCountry != 'Unknown') ...[
                    const Divider(height: 20),
                    _tripDetailRow(context, Icons.flag_outlined, 'Countries', '${trip.originCountry} → ${trip.destCountry}'),
                  ],
                  const Divider(height: 20),
                  _tripDetailRow(context, Icons.groups_outlined, 'Trip type', kTripTypes[trip.tripType] ?? trip.tripType),
                ],
              ),
            ),
            if (trip.id != null) ...[
              const SizedBox(height: 16),
              AttachmentStrip(
                key: ValueKey('trip-${trip.id}'),
                linkedType: 'trip',
                linkedId: trip.id!,
                title: 'Trip confirmations',
              ),
            ],
            const SizedBox(height: 16),
            TripBudgetPanel(
              key: ValueKey('budget-${trip.id}-${expenses.length}'),
              trip: trip,
              allExpenses: expenses,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BudgetBreakdownScreen(trip: trip)),
                  );
                },
                icon: const Icon(Icons.pie_chart_outline, size: 18),
                label: const Text('Split budget by category'),
              ),
            ),
            if (trip.attractions.isNotEmpty || trip.notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Notes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  [...trip.attractions, ...trip.notes].join('\n'),
                  style: GoogleFonts.inter(fontSize: 14, height: 1.45),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      onEdit?.call();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Trip'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

Container _buildStatusChip(String status, ColorScheme cs) {
  final color = switch (status.toUpperCase()) {
    'PLANNING' => Colors.blue,
    'READY' => Colors.orange,
    'ACTIVE' => Colors.green,
    'IDEA' => Colors.grey,
    _ => Colors.grey,
  };
  final label = switch (status.toUpperCase()) {
    'PLANNING' => 'Planning',
    'READY' => 'Ready',
    'ACTIVE' => 'Active',
    'IDEA' => 'Idea',
    'COMPLETED' => 'Completed',
    _ => status,
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
    child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}

Widget _tripDetailRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

String _currencySymbol(String currency) {
  const symbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'INR': '₹',
    'UZS': 'soʻm',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'SGD': 'S\$',
    'AUD': 'A\$',
    'CAD': 'C\$',
  };
  return symbols[currency.toUpperCase()] ?? currency.toUpperCase();
}

/// Opens the trip edit form. Returns true when the trip was saved, so callers
/// can reload. Shared so Home and Trips edit identically.
Future<bool> showTripEditSheet(BuildContext context, Trip trip) async {
  var saved = false;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) => CreateTripDialog(
      initialTrip: trip,
      onTripCreated: (updated) async {
        final data = updated.toMap()..remove('id');
        data['updated_at'] = DateTime.now().toIso8601String();
        await DatabaseHelper().update('trips', data, where: 'id = ?', whereArgs: [trip.id]);
        saved = true;
      },
    ),
  );
  return saved;
}
