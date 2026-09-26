import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  bool _showArchived = false;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final db = await DatabaseHelper().database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (_filterStatus != 'all') {
      where = 'status = ?';
      whereArgs = [_filterStatus];
    }

    final trips = await db.query(
      'trips',
      where: where.isEmpty ? null : where,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'departure ASC',
    );
    setState(() {
      _trips = trips.map((m) => Trip.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    setState(() {
      _showArchived = false;
    });
    _loadTrips();
  }

  Future<void> _deleteTrip(Trip trip) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip?'),
        content: Text('Delete "${trip.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'filter') {
                  // Show filter options
                } else if (value == 'archived') {
                  setState(() => _showArchived = !_showArchived);
                }
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'filter', child: Text('Filter by status')),
              PopupMenuItem(
                value: 'archived',
                child: Row(
                  children: [
                    Icon(
                      _showArchived ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(_showArchived ? 'Hide completed' : 'Show completed'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      return _TripCard(
                        trip: trip,
                        onTap: () => _navigateToTripDetail(trip),
                        onDelete: () => _deleteTrip(trip),
                        onEdit: () {},
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTripDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No trips yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start planning your next adventure',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
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

  void _navigateToTripDetail(Trip trip) {
    final controller = PageController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: PageView(
            controller: controller,
            children: [
              // Trip info page
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.originName} → ${trip.destName}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 20),
                    _detailTile(Icons.calendar_today, 'Departure', DateFormat('MMM d, y').format(trip.departure)),
                    _detailTile(Icons.calendar_today, 'Return', DateFormat('MMM d, y').format(trip.returnDate)),
                    _detailTile(Icons.people, 'Travelers', '${trip.travelers}'),
                    _detailTile(Icons.flight, 'Transport', trip.transportLabel),
                    if (trip.originCountry != 'Unknown' && trip.destCountry != 'Unknown') ...[
                      _detailTile(Icons.flag, 'Route', '${trip.originCountry} → ${trip.destCountry}'),
                    ],
                    if (trip.totalBudget > 0)
                      _detailTile(Icons.attach_money, 'Budget', NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency)).format(trip.totalBudget)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _showCreateTripDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => CreateTripDialog(
        onTripCreated: (trip) {
          _loadTrips();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${trip.name} created')),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TripCard({
    required this.trip,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = trip.departure.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor(trip.status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.flight,
                      color: _statusColor(trip.status),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${trip.originName} → ${trip.destName}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _infoChip(context,
                    icon: Icons.calendar_today,
                    label: '${DateFormat('MMM d').format(trip.departure)} – ${DateFormat('MMM d').format(trip.returnDate)}',
                  ),
                  const SizedBox(width: 8),
                  _infoChip(context,
                    icon: Icons.people,
                    label: '${trip.travelers} traveler${trip.travelers > 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: 8),
                  _infoChip(context,
                    icon: Icons.local_shipping,
                    label: trip.transportLabel,
                  ),
                ],
              ),
              if ((trip.distance ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions_car, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.distance!.toStringAsFixed(0)} km',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    if (trip.travelTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        trip.travelTime!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusChip(context, trip.status),
                  if (trip.status == 'COMPLETED') ...[
                    const SizedBox(width: 8),
                    Text(
                      '${trip.nights} nights',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                  const Spacer(),
                  if (trip.totalBudget > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Budget',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        Text(
                          NumberFormat.currency(symbol: _currencySymbol(trip.baseCurrency))
                              .format(trip.totalBudget),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
              if (daysUntil > 0 && trip.status != 'COMPLETED') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (daysUntil <= 7 ? Colors.orange : Colors.blue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    daysUntil <= 0
                        ? 'Departed'
                        : daysUntil == 1
                            ? 'Departs tomorrow!'
                            : 'Departs in $daysUntil days',
                    style: TextStyle(
                      color: daysUntil <= 7 ? Colors.orange : Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _infoChip(BuildContext ctx, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IDEA':
        return Colors.grey;
      case 'PLANNING':
        return Colors.blue;
      case 'READY':
        return Colors.orange;
      case 'ACTIVE':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(BuildContext ctx, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _statusColor(status),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _currencySymbol(String currency) {
    final symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'INR': '₹',
    };
    return symbols[currency] ?? currency;
  }
}

