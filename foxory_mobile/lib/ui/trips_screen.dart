import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../ui/create_trip_dialog.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final db = await DatabaseHelper().database;
    final where = _filterStatus == 'all' ? null : 'status = ?';
    final whereArgs = _filterStatus == 'all' ? null : [_filterStatus];
    final trips = await db.query('trips', where: where, whereArgs: whereArgs, orderBy: 'departure ASC');
    // Pre-fetch hotel counts per trip
    final hotelsByTrip = <int, int>{};
    for (final t in trips) {
      final tid = t['id'] as int;
      final h = await db.rawQuery('SELECT COUNT(*) as c FROM hotels WHERE trip_id = ?', [tid]);
      hotelsByTrip[tid] = (h.first['c'] as int?) ?? 0;
    }
    setState(() {
      _trips = trips.map((m) => Trip.fromMap(m)).toList();
      _hotelsByTrip = hotelsByTrip;
      _isLoading = false;
    });
  }

  /// Hotels count per trip id ( populated by _loadTrips ).
  Map<int, int> _hotelsByTrip = {};


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('My Trips', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              setState(() => _filterStatus = v);
              _loadTrips();
            },
            itemBuilder: (c) => [
              const PopupMenuItem(value: 'all', child: Text('All trips')),
              const PopupMenuItem(value: 'IDEA', child: Text('Ideas')),
              const PopupMenuItem(value: 'PLANNING', child: Text('Planning')),
              const PopupMenuItem(value: 'READY', child: Text('Ready')),
              const PopupMenuItem(value: 'ACTIVE', child: Text('Active')),
              const PopupMenuItem(value: 'COMPLETED', child: Text('Completed')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _emptyState(colorScheme)
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _trips.length,
                    itemBuilder: (c, i) => _tripCard(context, _trips[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTripDialog(context),
        icon: const Icon(Icons.add),
        label: Text('New Trip', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _emptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flight_takeoff, size: 80, color: colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No trips yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Start planning your next adventure', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateTripDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create First Trip'),
          ),
        ],
      ),
    );
  }

  Widget _tripCard(BuildContext context, Trip trip) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateRange = '${DateFormat('MMM d').format(trip.departure)} – ${DateFormat('MMM d, y').format(trip.returnDate)}';
    final nights = trip.nights <= 0 ? 'Day trip' : '${trip.nights} night${trip.nights == 1 ? '' : 's'}';
    final budgetText = trip.totalBudget > 0
        ? NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget)
        : 'No budget';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showTripDetail(context, trip),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _statusColor(trip.status).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.flight_takeoff, color: _statusColor(trip.status), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                trip.originName,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward, size: 15, color: colorScheme.primary),
                            ),
                            Expanded(
                              child: Text(
                                trip.destName,
                                textAlign: TextAlign.end,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(trip.status, colorScheme),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tripInfoPill(Icons.calendar_month, dateRange),
                  _tripInfoPill(Icons.hotel_outlined, nights),
                  _tripInfoPill(Icons.people_outline, '${trip.travelers} traveler${trip.travelers == 1 ? '' : 's'}'),
                  _tripInfoPill(Icons.directions_transit_outlined, trip.transportLabel),
                  if ((_hotelsByTrip[trip.id] ?? 0) > 0)
                    _tripInfoPill(Icons.hotel, '${_hotelsByTrip[trip.id]} hotel${_hotelsByTrip[trip.id] == 1 ? '' : 's'}'),
                  _tripInfoPill(Icons.account_balance_wallet_outlined, budgetText),
                ],
              ),
              if (trip.destinationImage != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    trip.destinationImage!,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 140,
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 32)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tripInfoPill(IconData icon, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.76),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colorScheme) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IDEA': return Colors.grey;
      case 'PLANNING': return Colors.blue;
      case 'READY': return Colors.orange;
      case 'ACTIVE': return Colors.green;
      case 'COMPLETED': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _currencySymbol(String currency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'INR': '₹',
      'JPY': '¥',
      'CNY': '¥',
      'KRW': '₩',
      'SGD': 'S\$',
      'AUD': 'A\$',
      'CAD': 'C\$',
    };
    return symbols[currency] ?? currency;
  }

  void _showTripDetail(BuildContext context, Trip trip) {
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
                  _detailRow(Icons.calendar_month, 'Dates', dateRange),
                  const Divider(height: 20),
                  _detailRow(Icons.hotel_outlined, 'Length', trip.nights <= 0 ? 'Day trip' : '${trip.nights} nights'),
                  const Divider(height: 20),
                  _detailRow(Icons.people_outline, 'Travelers', '${trip.travelers}'),
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
                  _detailRow(Icons.directions_transit_outlined, 'Transport', trip.transportLabel),
                  const Divider(height: 20),
                  _detailRow(Icons.account_balance_wallet_outlined, 'Budget', budget),
                  if (trip.originCountry != 'Unknown' || trip.destCountry != 'Unknown') ...[
                    const Divider(height: 20),
                    _detailRow(Icons.flag_outlined, 'Countries', '${trip.originCountry} → ${trip.destCountry}'),
                  ],
                ],
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
                      _showEditTripDialog(context, trip);
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

  Widget _detailRow(IconData icon, String label, String value) {
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

  // Old compact detail row kept for future smaller layouts.
  // ignore: unused_element
  Widget _detailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
                Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateTripDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => CreateTripDialog(
        onTripCreated: (trip) async {
          await DatabaseHelper().insert('trips', trip.toMap()..remove('id'));
          await _loadTrips();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${trip.name} created')));
          }
        },
      ),
    );
  }

  void _showEditTripDialog(BuildContext context, Trip trip) {
    showModalBottomSheet(
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
          _loadTrips();
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} updated')));
          }
        },
      ),
    );
  }
}
