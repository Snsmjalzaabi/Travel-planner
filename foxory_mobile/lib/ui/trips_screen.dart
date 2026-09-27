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
    setState(() {
      _trips = trips.map((m) => Trip.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete "${trip.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && trip.id != null) {
      final db = await DatabaseHelper().database;
      await db.delete('trips', where: 'id = ?', whereArgs: [trip.id]);
      _loadTrips();
    }
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
          Icon(Icons.flight_takeoff, size: 80, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No trips yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),
          Text('Start planning your next adventure', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.4))),
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
    final daysUntil = trip.departure.difference(DateTime.now()).inDays;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTripDetail(context, trip),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Trip icon with status color
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(trip.status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flight, color: _statusColor(trip.status), size: 22),
              ),
              const SizedBox(width: 12),
              // Trip info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.originName} → ${trip.destName}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(trip.departure),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(trip.returnDate),
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                    if (trip.destinationImage != null)
                      const SizedBox(height: 8),
                    if (trip.destinationImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          trip.destinationImage!,
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 120,
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 32)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Status + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildStatusChip(trip.status, colorScheme),
                  const SizedBox(height: 8),
                  if (trip.totalBudget > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Budget',
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade500),
                        ),
                        Text(
                          NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ColorScheme colorScheme) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.15),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${trip.originName} → ${trip.destName}', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.6))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _detailTile(Icons.calendar_today, 'Departure', DateFormat('MMM d, y').format(trip.departure)),
                        _detailTile(Icons.calendar_today, 'Return', DateFormat('MMM d, y').format(trip.returnDate)),
                        _detailTile(Icons.people, 'Travelers', '${trip.travelers}'),
                        _detailTile(Icons.flight, 'Transport', trip.transportLabel),
                        if (trip.originCountry != 'Unknown' && trip.destCountry != 'Unknown')
                          _detailTile(Icons.flag, 'Route', '${trip.originCountry} → ${trip.destCountry}'),
                        if (trip.totalBudget > 0)
                          _detailTile(Icons.attach_money, 'Budget', NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget)),
                        if (trip.destinationImage != null)
                          _detailTile(Icons.place, 'Destination', trip.destName),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(c);
                          _showEditTripDialog(context, trip);
                        },
                        child: const Text('Edit Trip'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

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
        onTripCreated: (trip) {
          _loadTrips();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${trip.name} created')));
        },
      ),
    );
  }

  void _showEditTripDialog(BuildContext context, Trip trip) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit trip — coming soon')));
  }
}
