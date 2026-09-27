import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../core/theme.dart';

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
    final trips = await db.query('trips', where: 'status != ?', whereArgs: ['COMPLETED'], orderBy: 'departure ASC');
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Planner', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Shared with me',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared trips — coming soon'))),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tripsWithPlanner.isEmpty
              ? _emptyState(colorScheme)
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildPlannerTabs(colorScheme)),
                    SliverList(
                      delegate: SliverChildListDelegate(
                        _tripsWithPlanner.map((trip) => _TripPlannerCard(
                          trip: trip,
                          isSelected: trip.id == _selectedTripId,
                          onTap: () => setState(() => _selectedTripId = trip.id),
                        )).toList(),
                      ),
                    ),
                    if (_selectedTrip != null)
                      SliverToBoxAdapter(child: _buildSelectedTripSection(context, colorScheme)),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddToPlannerDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Add to planner',
      ),
    );
  }

  Widget _emptyState(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No active trips', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),
          Text('Create a trip to start planning', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildPlannerTabs(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          _plannerTab('Hotels', Icons.hotel, (_selectedTrip?.hotels?.isNotEmpty ?? false), colorScheme),
          _plannerTab('Flights', Icons.flight, (_selectedTrip?.flights?.isNotEmpty ?? false), colorScheme),
          _plannerTab('Itinerary', Icons.calendar_today, (_selectedTrip?.itineraryDays?.isNotEmpty ?? false), colorScheme),
          _plannerTab('Packing', Icons.inventory_2, (_selectedTrip?.packingItems?.isNotEmpty ?? false), colorScheme),
          const Spacer(),
          _plannerTab('Map', Icons.map, true, colorScheme),
        ],
      ),
    );
  }

  Widget _plannerTab(String label, IconData icon, bool hasItems, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasItems && _selectedTripId != null ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: hasItems && _selectedTripId != null ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: hasItems && _selectedTripId != null ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.5),
                  fontWeight: hasItems && _selectedTripId != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (hasItems) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '${_getTabCount(label)}',
                    style: GoogleFonts.inter(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.w600),
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
      case 'Hotels': return _selectedTrip!.tripHotels?.length ?? 0;
      case 'Flights': return _selectedTrip!.tripFlights?.length ?? 0;
      case 'Itinerary': return _selectedTrip!.itineraryDays?.length ?? 0;
      case 'Packing': return _selectedTrip!.packingItems?.length ?? 0;
      default: return 0;
    }
  }

  Widget _TripPlannerCard({required Trip trip, required bool isSelected, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected ? colorScheme.primary.withOpacity(0.1) : null,
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
                  color: colorScheme.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${trip.originName} → ${trip.destName}', style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
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

  Widget _buildSelectedTripSection(BuildContext context, ColorScheme colorScheme) {
    if (_selectedTrip == null) return const SizedBox();
    final t = _selectedTrip!;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Edit ${t.name} — coming soon'))),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${t.originName} → ${t.destName}', style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _plannerChip(Icons.hotel, 'Hotels', t.tripHotels?.length ?? 0, Colors.indigo),
              _plannerChip(Icons.flight, 'Flights', t.tripFlights?.length ?? 0, Colors.purple),
              _plannerChip(Icons.calendar_today, 'Itinerary', t.itineraryDays?.length ?? 0, Colors.teal),
              _plannerChip(Icons.inventory_2, 'Packing', t.packingItems?.length ?? 0, Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          if ((t.tripHotels ?? []).isNotEmpty || (t.tripFlights ?? []).isNotEmpty) _buildTimelineSection(context, colorScheme),
        ],
      ),
    );
  }

  Widget _plannerChip(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: color.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
            child: Text(
              count > 0 ? '$count' : '0',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection(BuildContext context, ColorScheme colorScheme) {
    final allEvents = <TimelineEvent>[];
    for (final flight in (_selectedTrip!.tripFlights ?? [])) {
      allEvents.add(TimelineEvent(type: 'flight', title: flight.airline, subtitle: '${flight.flightNumber} · ${flight.fromCity} → ${flight.toCity}', time: flight.departure, icon: Icons.flight, color: Colors.purple));
    }
    for (final hotel in (_selectedTrip!.tripHotels ?? [])) {
      allEvents.add(TimelineEvent(type: 'hotel', title: hotel.name, subtitle: '${hotel.checkIn.toLocal().toString().split(' ')[0]} – ${hotel.checkOut.toLocal().toString().split(' ')[0]}', time: hotel.checkIn, icon: Icons.hotel, color: Colors.indigo));
    }
    allEvents.sort((a, b) => a.time.compareTo(b.time));
    if (allEvents.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.primary)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, top: 16, left: 16, right: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add to Planner', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('What do you want to add?', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _addOption(Icons.hotel, 'Hotel', 'Add a hotel stay'),
            _addOption(Icons.flight, 'Flight', 'Add flight details'),
            _addOption(Icons.calendar_today, 'Itinerary Day', 'Add a day plan'),
            _addOption(Icons.inventory_2, 'Packing Item', 'Add to packing list'),
            _addOption(Icons.restaurant, 'Activity', 'Add an activity'),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))),
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
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(label),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.add_circle_outline),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
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
  TimelineEvent({required this.type, required this.title, required this.subtitle, required this.time, required this.icon, required this.color});
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
            decoration: BoxDecoration(color: event.color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(event.icon, color: event.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('MMM d').format(event.time), style: GoogleFonts.inter(fontSize: 10, color: Colors.grey.shade600)),
                Text(event.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(event.subtitle, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Column(
            children: [
              Text(DateFormat('HH:mm').format(event.time), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: event.color)),
            ],
          ),
        ],
      ),
    );
  }
}
