import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import 'hotel_booking_form.dart';

class PlannerScreen extends StatefulWidget {
  final bool isActive;

  const PlannerScreen({super.key, this.isActive = false});

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

  @override
  void didUpdateWidget(covariant PlannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _loadTrips();
    }
  }

  Future<void> _loadTrips() async {
    // Load all saved trips (status casing varies historically, so no filter)
    // and attach hotels/flights/itinerary/packing so counts are real.
    final loadedTrips = await DatabaseHelper().loadTripsWithRelations();
    setState(() {
      _tripsWithPlanner = loadedTrips;
      _selectedTripId ??= loadedTrips.isNotEmpty ? loadedTrips.first.id : null;
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
          Icon(Icons.calendar_today_outlined, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No active trips', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 8),
          Text('Create a trip to start planning', style: GoogleFonts.inter(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildPlannerTabs(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          _plannerTab('Hotels', Icons.hotel, _selectedTrip!.hotels.isNotEmpty, colorScheme),
          _plannerTab('Flights', Icons.flight, _selectedTrip!.flights.isNotEmpty, colorScheme),
          _plannerTab('Itinerary', Icons.calendar_today, _selectedTrip!.itineraryDays.isNotEmpty, colorScheme),
          _plannerTab('Packing', Icons.inventory_2, _selectedTrip!.packingItems.isNotEmpty, colorScheme),
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
            color: hasItems && _selectedTripId != null ? colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: hasItems && _selectedTripId != null ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: hasItems && _selectedTripId != null ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.5),
                  fontWeight: hasItems && _selectedTripId != null ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              if (hasItems) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
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
      case 'Hotels': return _selectedTrip!.tripHotels.length;
      case 'Flights': return _selectedTrip!.tripFlights.length;
      case 'Itinerary': return _selectedTrip!.itineraryDays.length;
      case 'Packing': return _selectedTrip!.packingItems.length;
      default: return 0;
    }
  }

  Widget _TripPlannerCard({required Trip trip, required bool isSelected, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : null,
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
                  color: colorScheme.primary.withValues(alpha: 0.5),
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
                    Text('${trip.originName} → ${trip.destName}', style: GoogleFonts.inter(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)), maxLines: 1, overflow: TextOverflow.ellipsis),
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
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2), width: 2),
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
          Text('${t.originName} → ${t.destName}', style: GoogleFonts.inter(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _plannerChip(Icons.hotel, 'Hotels', t.tripHotels.length, Colors.indigo),
              _plannerChip(Icons.flight, 'Flights', t.tripFlights.length, Colors.purple),
              _plannerChip(Icons.calendar_today, 'Itinerary', t.itineraryDays.length, Colors.teal),
              _plannerChip(Icons.inventory_2, 'Packing', t.packingItems.length, Colors.amber),
            ],
          ),
          const SizedBox(height: 16),
          if (t.tripHotels.isNotEmpty || t.tripFlights.isNotEmpty) _buildTimelineSection(context, colorScheme),
        ],
      ),
    );
  }

  Widget _plannerChip(IconData icon, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
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
    for (final flight in _selectedTrip!.tripFlights) {
      allEvents.add(TimelineEvent(type: 'flight', title: flight.airline, subtitle: '${flight.flightNumber} · ${flight.fromCity} → ${flight.toCity}', time: flight.departure, icon: Icons.flight, color: Colors.purple));
    }
    for (final hotel in _selectedTrip!.tripHotels) {
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
    final trip = _selectedTrip;
    if (trip == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a trip first')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.40,
        maxChildSize: 0.90,
        builder: (sheetContext, controller) => ListView(
          controller: controller,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Add to Planner', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Adding to ${trip.name}', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            _addOption(Icons.hotel, 'Hotel', 'Add a hotel stay', () => _openHotelForm(trip.id!)),
            _addOption(Icons.flight, 'Flight', 'Add flight details', () => _showFlightForm(trip)),
            _addOption(Icons.calendar_today, 'Itinerary Day', 'Add a day plan', () => _showItineraryDayForm(trip)),
            _addOption(Icons.inventory_2, 'Packing Item', 'Add to packing list', () => _showPackingItemForm(trip)),
            _addOption(Icons.restaurant, 'Activity', 'Add a planned activity', () => _showActivityForm(trip)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel'))),
          ],
        ),
      ),
    );
  }


  Widget _addOption(IconData icon, String label, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(label),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
      ),
    );
  }
  void _openHotelForm(int tripId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HotelBookingForm(preselectedTripId: tripId)),
    ).then((_) => _loadTrips());
  }

  Future<void> _showFlightForm(Trip trip) async {
    final airlineCtrl = TextEditingController();
    final flightNoCtrl = TextEditingController();
    final fromCtrl = TextEditingController(text: trip.originName == 'Unknown' ? '' : trip.originName);
    final toCtrl = TextEditingController(text: trip.destName == 'Unknown' ? '' : trip.destName);
    DateTime departure = trip.departure;
    DateTime arrival = trip.departure;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Flight', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(controller: airlineCtrl, decoration: const InputDecoration(labelText: 'Airline', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: flightNoCtrl, decoration: const InputDecoration(labelText: 'Flight number', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From city', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'To city', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text('Departure: ${DateFormat('MMM d, y').format(departure)}'),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: departure, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 1095)));
                    if (d != null) setSheetState(() { departure = d; arrival = d; });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final now = DateTime.now().toIso8601String();
                      await DatabaseHelper().insert('flights', {
                        'trip_id': trip.id,
                        'airline': airlineCtrl.text.trim().isEmpty ? 'Flight' : airlineCtrl.text.trim(),
                        'flight_number': flightNoCtrl.text.trim().isEmpty ? 'TBD' : flightNoCtrl.text.trim(),
                        'from_city': fromCtrl.text.trim().isEmpty ? trip.originName : fromCtrl.text.trim(),
                        'from_country': trip.originCountry,
                        'to_city': toCtrl.text.trim().isEmpty ? trip.destName : toCtrl.text.trim(),
                        'to_country': trip.destCountry,
                        'departure': departure.toIso8601String(),
                        'arrival': arrival.toIso8601String(),
                        'departure_terminal': '',
                        'arrival_terminal': '',
                        'departure_gate': '',
                        'arrival_gate': '',
                        'currency': trip.baseCurrency,
                        'seat': '',
                        'status': 'CONFIRMED',
                        'notes': '',
                        'bookmarked': 0,
                        'duration_minutes': 0,
                        'created_at': now,
                        'updated_at': now,
                        'sync_enabled': 1,
                        'sync_status': 0,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _loadTrips();
                    },
                    child: const Text('Save Flight'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showItineraryDayForm(Trip trip) async {
    final themeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = trip.departure;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add Itinerary Day', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(controller: themeCtrl, decoration: const InputDecoration(labelText: 'Theme / title', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('MMM d, y').format(date)),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: trip.departure.subtract(const Duration(days: 30)), lastDate: trip.returnDate.add(const Duration(days: 30)));
                  if (d != null) setSheetState(() => date = d);
                },
              ),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                final db = await DatabaseHelper().database;
                final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM itinerary_days WHERE trip_id = ?', [trip.id])) ?? 0;
                final now = DateTime.now().toIso8601String();
                await DatabaseHelper().insert('itinerary_days', {
                  'trip_id': trip.id,
                  'day_number': count + 1,
                  'date': date.toIso8601String(),
                  'theme': themeCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                  'order_index': count,
                  'created_at': now,
                  'updated_at': now,
                  'sync_enabled': 1,
                  'sync_status': 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadTrips();
              }, child: const Text('Save Day'))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPackingItemForm(Trip trip) async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Clothes');
    final qtyCtrl = TextEditingController(text: '1');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add Packing Item', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item name', border: OutlineInputBorder()), autofocus: true),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
            if (nameCtrl.text.trim().isEmpty) return;
            final now = DateTime.now().toIso8601String();
            await DatabaseHelper().insert('packing_items', {
              'trip_id': trip.id,
              'category': categoryCtrl.text.trim().isEmpty ? 'Misc' : categoryCtrl.text.trim(),
              'name': nameCtrl.text.trim(),
              'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 1,
              'unit': '',
              'packed': 0,
              'essential': 0,
              'notes': '',
              'packed_at_minutes': 0,
              'packed_now': 0,
              'created_at': now,
              'updated_at': now,
              'sync_status': 0,
              'sync_enabled': 1,
            });
            if (ctx.mounted) Navigator.pop(ctx);
            await _loadTrips();
          }, child: const Text('Save Item'))),
        ]),
      ),
    );
  }

  Future<void> _showActivityForm(Trip trip) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime date = trip.departure;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 16, left: 16, right: 16, top: 16),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Add Activity', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Activity title', border: OutlineInputBorder()), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today), title: Text(DateFormat('MMM d, y').format(date)), onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: date, firstDate: trip.departure.subtract(const Duration(days: 30)), lastDate: trip.returnDate.add(const Duration(days: 30)));
                if (d != null) setSheetState(() => date = d);
              }),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final db = await DatabaseHelper().database;
                final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM itinerary_activities WHERE trip_id = ?', [trip.id])) ?? 0;
                final dayNumber = date.difference(trip.departure).inDays + 1;
                final now = DateTime.now().toIso8601String();
                await DatabaseHelper().insert('itinerary_activities', {
                  'trip_id': trip.id,
                  'day_number': dayNumber < 1 ? 1 : dayNumber,
                  'order_index': count,
                  'title': titleCtrl.text.trim(),
                  'description': notesCtrl.text.trim(),
                  'start_time': date.toIso8601String(),
                  'end_time': date.toIso8601String(),
                  'category': 'activity',
                  'location': locationCtrl.text.trim(),
                  'currency': trip.baseCurrency,
                  'duration_minutes': 0,
                  'done': 0,
                  'important': 0,
                  'reminder_minutes': 0,
                  'created_at': now,
                  'updated_at': now,
                  'sync_enabled': 1,
                  'sync_status': 0,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadTrips();
              }, child: const Text('Save Activity'))),
            ]),
          ),
        ),
      ),
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
            decoration: BoxDecoration(color: event.color.withValues(alpha: 0.2), shape: BoxShape.circle),
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
