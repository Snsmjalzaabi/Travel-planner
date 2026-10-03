import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../ui/create_trip_dialog.dart';
import 'trip_detail_sheet.dart';

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
    final expenseRows = await db.query('expenses', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
    final all = await DatabaseHelper().loadTripsWithRelations();
    final trips = all.where((t) => _matchesStatus(t.status)).toList();
    final expenses = expenseRows.map(Expense.fromMap).toList();
    final hotelsByTrip = <int, int>{
      for (final t in trips)
        if (t.id != null) t.id!: t.hotels.length,
    };
    setState(() {
      _trips = trips;
      _expenses = expenses;
      _hotelsByTrip = hotelsByTrip;
      _isLoading = false;
    });
  }

  /// Hotels count per trip id ( populated by _loadTrips ).
  Map<int, int> _hotelsByTrip = {};

  /// Kept in memory so the budget panel in the trip sheet is live.
  List<Expense> _expenses = [];


  /// Trip statuses, stored lowercase by the create/edit form.
  static const _statusFilters = [
    (value: 'IDEA', label: 'Ideas'),
    (value: 'PLANNING', label: 'Planning'),
    (value: 'READY', label: 'Ready'),
    (value: 'ACTIVE', label: 'Active'),
    (value: 'COMPLETED', label: 'Completed'),
  ];

  String _statusLabel(String status) {
    final upper = status.toUpperCase();
    for (final f in _statusFilters) {
      if (f.value == upper) return f.label;
    }
    return status.isEmpty ? 'Unknown' : status;
  }

  bool _matchesStatus(String status) {
    if (_filterStatus == 'all') return true;
    return status.toUpperCase() == _filterStatus.toUpperCase();
  }

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
              for (final s in _statusFilters)
                PopupMenuItem(value: s.value, child: Text(s.label)),
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
        _statusLabel(status),
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
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
      'UZS': 'soʻm',
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
    showTripDetailSheet(
      context,
      trip,
      expenses: _expenses,
      onChanged: _loadTrips,
      onEdit: () => _showEditTripDialog(context, trip),
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
