import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import 'hotel_booking_form.dart';
import 'create_trip_dialog.dart';
import 'trip_budget_panel.dart';
import '../services/soft_delete.dart';

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

  /// Which planner section is open: 'hotels', 'flights', 'itinerary',
  /// 'packing' or 'all'.
  String _section = 'all';

  List<Expense> _expenses = [];

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
    final db = await DatabaseHelper().database;
    final expenseRows = await db.query('expenses', where: 'deleted_at IS NULL', orderBy: 'created_at DESC');
    final loadedTrips = await DatabaseHelper().loadTripsWithRelations();
    setState(() {
      _expenses = expenseRows.map(Expense.fromMap).toList();
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
    final trip = _selectedTrip;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              _plannerTab('All', Icons.dashboard_outlined, null, colorScheme),
              _plannerTab('Hotels', Icons.hotel, trip?.tripHotels.length, colorScheme),
              _plannerTab('Flights', Icons.flight, trip?.tripFlights.length, colorScheme),
              _plannerTab('Itinerary', Icons.calendar_today, trip?.itineraryDays.length, colorScheme),
              _plannerTab('Activities', Icons.place, trip?.activities.length, colorScheme),
              _plannerTab('Packing', Icons.inventory_2, trip?.packingItems.length, colorScheme),
              _plannerTab('Budget', Icons.account_balance_wallet_outlined, null, colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plannerTab(String label, IconData icon, int? count, ColorScheme colorScheme) {
    final selected = _section == _sectionKey(label);
    final has = (count ?? 0) > 0;
    final fg = selected
        ? colorScheme.primary
        : (has ? colorScheme.onSurface.withValues(alpha: 0.75) : colorScheme.onSurface.withValues(alpha: 0.45));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: () => setState(() => _section = _sectionKey(label)),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: count > 0 ? colorScheme.primary.withValues(alpha: 0.18) : colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.inter(fontSize: 10, color: count > 0 ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _sectionKey(String label) => label.toLowerCase() == 'all' ? 'all' : label.toLowerCase();

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

  Widget _buildSelectedTripSection(BuildContext context, ColorScheme cs) {
    final t = _selectedTrip;
    if (t == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () => _showEditTripFromPlanner(context, t),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit trip',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${t.originName} → ${t.destName}', style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 14),
          ..._sectionWidgets(context, cs, t),
        ],
      ),
    );
  }

  List<Widget> _sectionWidgets(BuildContext context, ColorScheme cs, Trip t) {
    switch (_section) {
      case 'hotels':
        return [_listBlock(cs, 'Hotels', Icons.hotel,
            t.tripHotels.map((h) => _hotelTile(cs, h)).toList(),
            () => _openHotelForm(t.id!))];
      case 'flights':
        return [_listBlock(cs, 'Flights', Icons.flight,
            t.tripFlights.map((f) => _flightTile(cs, f)).toList(),
            () => _showFlightForm(t))];
      case 'itinerary':
        return [
          _listBlock(cs, 'Itinerary days', Icons.calendar_today,
              t.itineraryDays.map((d) => _dayTile(cs, d)).toList(),
              () => _showItineraryDayForm(t)),
        ];
      case 'activities':
        return [
          _listBlock(cs, 'Activities', Icons.place,
              t.activities.map((a) => _activityTile(cs, a)).toList(),
              () => _showActivityForm(t)),
        ];
      case 'packing':
        return [
          _listBlock(cs, 'Packing list', Icons.inventory_2,
              t.packingItems.map((i) => _packingTile(cs, i)).toList(),
              () => _showPackingItemForm(t)),
        ];
      case 'budget':
        return [
          TripBudgetPanel(
            key: ValueKey('budget-${t.id}-${_expenses.length}'),
            trip: t,
            allExpenses: _expenses,
          ),
          const SizedBox(height: 12),
          Text(
            'Expenses tagged to this trip count towards its budget. Add them from the Expenses tab.',
            style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
          ),
        ];
      default:
        return _overviewBlocks(cs, t);
    }
  }

  List<Widget> _overviewBlocks(ColorScheme cs, Trip t) {
    final blocks = <Widget>[];

    Widget? block(String title, IconData icon, int count, List<Widget> children, VoidCallback onAdd, Color color) {
      if (children.isEmpty) return null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('$count', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
              const Spacer(),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
          const SizedBox(height: 16),
        ],
      );
    }

    for (final b in [
      block('Hotels', Icons.hotel, t.tripHotels.length, t.tripHotels.map((h) => _hotelTile(cs, h)).toList(), () => _openHotelForm(t.id!), Colors.indigo),
      block('Flights', Icons.flight, t.tripFlights.length, t.tripFlights.map((f) => _flightTile(cs, f)).toList(), () => _showFlightForm(t), Colors.purple),
      block('Itinerary days', Icons.calendar_today, t.itineraryDays.length, t.itineraryDays.map((d) => _dayTile(cs, d)).toList(), () => _showItineraryDayForm(t), Colors.teal),
      block('Activities', Icons.place, t.activities.length, t.activities.map((a) => _activityTile(cs, a)).toList(), () => _showActivityForm(t), Colors.green),
      block('Packing list', Icons.inventory_2, t.packingItems.length, t.packingItems.map((i) => _packingTile(cs, i)).toList(), () => _showPackingItemForm(t), Colors.amber),
    ]) {
      if (b != null) blocks.add(b);
    }

    if (t.tripHotels.isNotEmpty || t.tripFlights.isNotEmpty) {
      blocks.add(_buildTimelineSection(context, cs));
    }
    if (blocks.isEmpty) {
      blocks.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Nothing planned yet. Use the + button to add hotels, flights, itinerary days, activities or packing items.',
          style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
        ),
      ));
    }
    return blocks;
  }

  Widget _listBlock(ColorScheme cs, String title, IconData icon, List<Widget> children, VoidCallback onAdd) {
    if (children.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: cs.primary),
            const SizedBox(width: 6),
            Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, size: 26, color: cs.onSurface.withValues(alpha: 0.25)),
                const SizedBox(height: 8),
                Text('Nothing here yet', style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text('Add'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 15, color: cs.primary),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ]),
        const SizedBox(height: 6),
        ...children,
      ],
    );
  }

  // ---------- item tiles ----------

  Widget _row(ColorScheme cs, {required Widget child, required VoidCallback onEdit, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: child),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            onPressed: onEdit,
            visualDensity: VisualDensity.compact,
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _hotelTile(ColorScheme cs, Hotel h) {
    return _row(
      cs,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              '${DateFormat('MMM d').format(h.checkIn)} – ${DateFormat('MMM d, y').format(h.checkOut)} • ${h.city}',
              style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            if (h.confirmationNumber != null && h.confirmationNumber!.isNotEmpty)
              Text('Ref ${h.confirmationNumber}', style: GoogleFonts.inter(fontSize: 11, color: cs.primary)),
          ],
        ),
      ),
      onEdit: () => _showHotelEditForm(h),
      onDelete: () => _deleteRow('hotels', h.id, '${h.name} deleted'),
    );
  }

  Widget _flightTile(ColorScheme cs, Flight f) {
    return _row(
      cs,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.airline} ${f.flightNumber}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text('${f.fromCity} → ${f.toCity}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
            Text(
              '${DateFormat('MMM d').format(f.departure)} • ${DateFormat('HH:mm').format(f.departure)}–${DateFormat('HH:mm').format(f.arrival)}',
              style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
      onEdit: () => _showFlightEditForm(f),
      onDelete: () => _deleteRow('flights', f.id, '${f.airline} flight deleted'),
    );
  }

  Widget _dayTile(ColorScheme cs, ItineraryDay d) {
    return _row(
      cs,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${d.dayNumber}${d.theme != null && d.theme!.isNotEmpty ? ' — ${d.theme}' : ''}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(DateFormat('EEEE, MMM d, y').format(d.date), style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
            if (d.notes.isNotEmpty) Text(d.notes, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
      onEdit: () => _showDayEditForm(d),
      onDelete: () => _deleteRow('itinerary_days', d.id, 'Day ${d.dayNumber} deleted'),
    );
  }

  Widget _activityTile(ColorScheme cs, ItineraryActivity a) {
    return _row(
      cs,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            if (a.startTime != null)
              Text(DateFormat('MMM d • HH:mm').format(a.startTime!), style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
            if (a.location != null && a.location!.isNotEmpty)
              Text(a.location!, style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
      onEdit: () => _showActivityEditForm(a),
      onDelete: () => _deleteRow('itinerary_activities', a.id, 'Activity deleted'),
    );
  }

  Widget _packingTile(ColorScheme cs, PackingItem i) {
    return InkWell(
      onTap: () async {
        await DatabaseHelper().update('packing_items', {'packed': i.packed ? 0 : 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [i.id]);
        await _loadTrips();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Checkbox(
                value: i.packed,
                onChanged: (_) async {
                  await DatabaseHelper().update('packing_items', {'packed': i.packed ? 0 : 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [i.id]);
                  await _loadTrips();
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: i.packed ? TextDecoration.lineThrough : null,
                        color: i.packed ? cs.onSurface.withValues(alpha: 0.45) : null,
                      ),
                    ),
                    Text('${i.category}${i.quantity > 1 ? ' • x${i.quantity}' : ''}', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: () => _deleteRow('packing_items', i.id, '${i.name} removed'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRow(String table, int? id, String message) async {
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    // Soft delete: a restore must not bring this row back.
    final db = await DatabaseHelper().database;
    await softDelete(db, table, id);
    await _loadTrips();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // ---------- edit forms ----------

  void _showEditTripFromPlanner(BuildContext context, Trip trip) {
    Navigator.pop(context);
    _showEditTripDialog(trip);
  }

  void _showEditTripDialog(Trip trip) {
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
          await _loadTrips();
        },
      ),
    );
  }

  void _showHotelEditForm(Hotel hotel) {
    final nameCtrl = TextEditingController(text: hotel.name);
    final addressCtrl = TextEditingController(text: hotel.address);
    final cityCtrl = TextEditingController(text: hotel.city);
    final countryCtrl = TextEditingController(text: hotel.country);
    final confCtrl = TextEditingController(text: hotel.confirmationNumber ?? '');
    final costCtrl = TextEditingController(text: hotel.cost?.toStringAsFixed(0) ?? '');
    String currency = hotel.currency;
    DateTime checkIn = hotel.checkIn;
    DateTime checkOut = hotel.checkOut;

    _showEditSheet(
      title: 'Edit hotel',
      saveLabel: 'Update',
      onSave: () async {
        await DatabaseHelper().update('hotels', {
          'name': nameCtrl.text.trim().isEmpty ? hotel.name : nameCtrl.text.trim(),
          'address': addressCtrl.text.trim(),
          'city': cityCtrl.text.trim(),
          'country': countryCtrl.text.trim(),
          'check_in': checkIn.toIso8601String(),
          'check_out': checkOut.toIso8601String(),
          'confirmation_number': confCtrl.text.trim(),
          'cost': double.tryParse(costCtrl.text.trim()),
          'currency': currency,
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [hotel.id]);
        await _loadTrips();
      },
      builder: (setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Hotel name', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: 'City', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: countryCtrl, decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _editDateField('Check-in', checkIn, (d) => setSheet(() => checkIn = d))),
            const SizedBox(width: 8),
            Expanded(child: _editDateField('Check-out', checkOut, (d) => setSheet(() => checkOut = d))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: confCtrl, decoration: const InputDecoration(labelText: 'Confirmation #', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 8),
            Expanded(child: _editDropdown('Currency', currency, const ['USD', 'EUR', 'GBP', 'AED', 'INR', 'UZS'], (v) => setSheet(() => currency = v))),
          ]),
        ],
      ),
    );
  }

  void _showFlightEditForm(Flight f) {
    final airlineCtrl = TextEditingController(text: f.airline);
    final numberCtrl = TextEditingController(text: f.flightNumber);
    final fromCtrl = TextEditingController(text: f.fromCity);
    final toCtrl = TextEditingController(text: f.toCity);
    final seatCtrl = TextEditingController(text: f.seat);
    String status = f.status;
    DateTime departure = f.departure;
    DateTime arrival = f.arrival;

    _showEditSheet(
      title: 'Edit flight',
      saveLabel: 'Update',
      onSave: () async {
        await DatabaseHelper().update('flights', {
          'airline': airlineCtrl.text.trim(),
          'flight_number': numberCtrl.text.trim(),
          'from_city': fromCtrl.text.trim(),
          'to_city': toCtrl.text.trim(),
          'seat': seatCtrl.text.trim(),
          'status': status,
          'departure': departure.toIso8601String(),
          'arrival': arrival.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [f.id]);
        await _loadTrips();
      },
      builder: (setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: TextField(controller: airlineCtrl, decoration: const InputDecoration(labelText: 'Airline', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Flight no.', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: fromCtrl, decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: toCtrl, decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _editDateField('Departure', departure, (d) => setSheet(() { departure = d; arrival = d; }))),
            const SizedBox(width: 8),
            Expanded(child: _editDateField('Arrival', arrival, (d) => setSheet(() => arrival = d))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: seatCtrl, decoration: const InputDecoration(labelText: 'Seat', border: OutlineInputBorder()))),
            const SizedBox(width: 8),
            Expanded(child: _editDropdown('Status', status, const ['CONFIRMED', 'BOARDING', 'DEPARTED', 'ARRIVED', 'DELAYED', 'CANCELLED'], (v) => setSheet(() => status = v))),
          ]),
        ],
      ),
    );
  }

  void _showDayEditForm(ItineraryDay d) {
    final themeCtrl = TextEditingController(text: d.theme ?? '');
    final notesCtrl = TextEditingController(text: d.notes);
    DateTime date = d.date;
    int dayNumber = d.dayNumber;

    _showEditSheet(
      title: 'Edit day',
      saveLabel: 'Update',
      onSave: () async {
        await DatabaseHelper().update('itinerary_days', {
          'theme': themeCtrl.text.trim(),
          'notes': notesCtrl.text.trim(),
          'date': date.toIso8601String(),
          'day_number': dayNumber,
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [d.id]);
        await _loadTrips();
      },
      builder: (setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: themeCtrl, decoration: const InputDecoration(labelText: 'Theme / title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _editDateField('Date', date, (v) => setSheet(() => date = v))),
            const SizedBox(width: 8),
            Expanded(child: _editNumberField('Day number', dayNumber, (v) => setSheet(() => dayNumber = v))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
        ],
      ),
    );
  }

  void _showActivityEditForm(ItineraryActivity a) {
    final titleCtrl = TextEditingController(text: a.title);
    final locationCtrl = TextEditingController(text: a.location ?? '');
    final descCtrl = TextEditingController(text: a.description ?? '');

    _showEditSheet(
      title: 'Edit activity',
      saveLabel: 'Update',
      onSave: () async {
        await DatabaseHelper().update('itinerary_activities', {
          'title': titleCtrl.text.trim().isEmpty ? a.title : titleCtrl.text.trim(),
          'location': locationCtrl.text.trim(),
          'description': descCtrl.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [a.id]);
        await _loadTrips();
      },
      builder: (setSheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: locationCtrl, decoration: const InputDecoration(labelText: 'Location', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 2),
        ],
      ),
    );
  }

  /// Shared chrome for the small edit sheets.
  void _showEditSheet({
    required String title,
    required String saveLabel,
    required Future<void> Function() onSave,
    required Widget Function(StateSetter setSheet) builder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 16, right: 16, top: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                builder(setSheet),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await onSave();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(saveLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _editDateField(String label, DateTime value, ValueChanged<DateTime> onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(1990),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(DateFormat('MMM d, y').format(value), style: GoogleFonts.inter(fontSize: 14)),
      ),
    );
  }

  Widget _editNumberField(String label, int value, ValueChanged<int> onChanged) {
    final ctrl = TextEditingController(text: value.toString());
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
    );
  }

  Widget _editDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: options.contains(value) ? value : options.first,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
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
