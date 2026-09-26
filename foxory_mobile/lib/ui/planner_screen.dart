import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  List<Trip> _tripsWithPlanner = [];
  bool _isLoading = true;
  int? _selectedTripId;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final db = await DatabaseHelper().database;
    final trips = await db.query(
      'trips',
      where: 'status != ?',
      whereArgs: ['COMPLETED'],
      orderBy: 'departure ASC',
    );
    setState(() {
      _tripsWithPlanner = trips.map((m) => Trip.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  Trip? get _selectedTrip {
    if (_selectedTripId == null) return null;
    try {
      return _tripsWithPlanner.firstWhere((t) => t.id == _selectedTripId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Planner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Shared with me',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Shared trips — coming soon')),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tripsWithPlanner.isEmpty
              ? _buildEmptyState()
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildPlannerTabs(),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate(
                        _tripsWithPlanner.map((trip) => _TripPlannerCard(
                              trip: trip,
                              isSelected: trip.id == _selectedTripId,
                              onTap: () => setState(() => _selectedTripId = trip.id),
                            )).toList(),
                      ),
                    ),
                    if (_selectedTrip != null) ...[
                      SliverToBoxAdapter(
                        child: _buildSelectedTripSection(),
                      ),
                    ],
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddToPlannerDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Add to planner',
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No active trips',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a trip to start planning',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlannerTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          _plannerTab('Hotels', Icons.hotel, _selectedTrip?.tripHotels?.isNotEmpty ?? false),
          _plannerTab('Flights', Icons.flight, _selectedTrip?.tripFlights?.isNotEmpty ?? false),
          _plannerTab('Itinerary', Icons.calendar_today, _selectedTrip?.itineraryDays?.isNotEmpty ?? false),
          _plannerTab('Packing', Icons.inventory_2, _selectedTrip?.packingItems?.isNotEmpty ?? false),
          const Spacer(),
          _plannerTab('Map', Icons.map, true),
        ],
      ),
    );
  }

  Widget _plannerTab(String label, IconData icon, bool hasItems) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label — coming soon')),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (hasItems && _selectedTripId != null)
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: hasItems && _selectedTripId != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: hasItems && _selectedTripId != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: hasItems && _selectedTripId != null
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
              ),
              if (hasItems) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_getTabCount(label)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
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

  int _getTabCount(String label) {
    if (_selectedTrip == null) return 0;
    switch (label) {
      case 'Hotels':
        return _selectedTrip!.tripHotels?.length ?? 0;
      case 'Flights':
        return _selectedTrip!.tripFlights?.length ?? 0;
      case 'Itinerary':
        return _selectedTrip!.itineraryDays?.length ?? 0;
      case 'Packing':
        return _selectedTrip!.packingItems?.length ?? 0;
      default:
        return 0;
    }
  }

  Widget _TripPlannerCard({
    required Trip trip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.originName} → ${trip.destName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTripSection() {
    if (_selectedTrip == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedTrip!.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Edit ${_selectedTrip!.name} — coming soon')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_selectedTrip!.originName} → ${_selectedTrip!.destName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _plannerChip(
                icon: Icons.hotel,
                label: 'Hotels',
                count: (_selectedTrip!.hotels ?? []).length,
                color: Colors.indigo,
              ),
              _plannerChip(
                icon: Icons.flight,
                label: 'Flights',
                count: (_selectedTrip!.flights ?? []).length,
                color: Colors.purple,
              ),
              _plannerChip(
                icon: Icons.calendar_today,
                label: 'Itinerary Days',
                count: (_selectedTrip!.itineraryDays ?? []).length,
                color: Colors.teal,
              ),
              _plannerChip(
                icon: Icons.inventory_2,
                label: 'Packing Items',
                count: (_selectedTrip!.packingItems ?? []).length,
                color: Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ((_selectedTrip!.hotels ?? []).isNotEmpty ||
              (_selectedTrip!.flights ?? []).isNotEmpty)
            _buildTimelineSection(),
        ],
      ),
    );
  }

  Widget _plannerChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count > 0 ? '$count' : '0',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final allEvents = <TimelineEvent>[];

    // Add flights
    for (final flight in (_selectedTrip!.flights ?? [])) {
      allEvents.add(TimelineEvent(
        type: 'flight',
        title: flight.airline,
        subtitle: '${flight.flightNumber} · ${flight.fromCity} → ${flight.toCity}',
        time: flight.departure,
        icon: Icons.flight,
        color: Colors.purple,
      ));
    }

    // Add hotels
    for (final hotel in (_selectedTrip!.hotels ?? [])) {
      allEvents.add(TimelineEvent(
        type: 'hotel',
        title: hotel.name,
        subtitle: '${hotel.checkIn.toLocal().toString().split(' ')[0]} – ${hotel.checkOut.toLocal().toString().split(' ')[0]}',
        time: hotel.checkIn,
        icon: Icons.hotel,
        color: Colors.indigo,
      ));
    }

    // Sort by time
    allEvents.sort((a, b) => (a.time).compareTo(b.time));

    if (allEvents.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        ...allEvents.map((event) => _TimelineEventCard(event: event)),
      ],
    );
  }

  void _showAddToPlannerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Planner',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'What do you want to add?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 16),
            _addOption(Icons.hotel, 'Hotel', 'Add a hotel stay'),
            _addOption(Icons.flight, 'Flight', 'Add flight details'),
            _addOption(Icons.calendar_today, 'Itinerary Day', 'Add a day plan'),
            _addOption(Icons.inventory_2, 'Packing Item', 'Add to packing list'),
            _addOption(Icons.restaurant, 'Activity', 'Add an activity'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _addOption(IconData icon, String label, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(label),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () {
        Navigator.pop(context);
        switch (label) {
          case 'Hotel':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Hotel — coming soon')),
            );
            break;
          case 'Flight':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Flight — coming soon')),
            );
            break;
          case 'Itinerary Day':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Itinerary Day — coming soon')),
            );
            break;
          case 'Packing Item':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Packing Item — coming soon')),
            );
            break;
          case 'Activity':
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add Activity — coming soon')),
            );
            break;
        }
      },
    );
  }
}

class TimelineEvent {
  final String type;
  final String title;
  final String subtitle;
  final DateTime time;
  final IconData icon;
  final Color color;

  TimelineEvent({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.icon,
    required this.color,
  });
}

class _TimelineEventCard extends StatelessWidget {
  final TimelineEvent event;

  const _TimelineEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: event.color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(event.icon, color: event.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMM d').format(event.time),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                Text(
                  event.subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                DateFormat('HH:mm').format(event.time),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: event.color,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

