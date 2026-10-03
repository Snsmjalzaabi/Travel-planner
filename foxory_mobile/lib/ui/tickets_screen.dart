import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';

/// One bookable thing: a flight or a hotel stay, normalised so both can be
/// shown in a single chronological list.
class Ticket {
  final String kind; // 'flight' | 'hotel'
  final int id;
  final int? tripId;
  final String tripName;

  /// Sort key — when this ticket is used.
  final DateTime when;

  final String title;
  final String subtitle;

  /// Booking reference / confirmation number. Empty means not recorded yet.
  final String reference;

  final List<(String, String)> extras;

  const Ticket({
    required this.kind,
    required this.id,
    required this.tripId,
    required this.tripName,
    required this.when,
    required this.title,
    required this.subtitle,
    required this.reference,
    this.extras = const [],
  });
}

/// A single place to see every flight and hotel you have booked, with their
/// confirmation numbers in one place.
///
/// This is a read-only aggregate over the existing `flights` and `hotels`
/// tables rather than a new `tickets` table — the data was already there and
/// duplicating it would only create drift.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<Ticket> _tickets = [];
  bool _isLoading = true;
  String _filter = 'all'; // all | flight | hotel | missing

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;

    final tripRows = await db.query('trips', where: 'deleted_at IS NULL', orderBy: 'departure ASC');
    final tripNames = <int, String>{
      for (final r in tripRows) r['id'] as int: (r['name'] as String?) ?? 'Trip',
    };

    final flights = await db.query(
      'flights',
      where: 'deleted_at IS NULL',
      orderBy: 'departure ASC',
    );
    final hotels = await db.query(
      'hotels',
      where: 'deleted_at IS NULL',
      orderBy: 'check_in ASC',
    );

    final tickets = <Ticket>[];

    for (final f in flights) {
      final tripId = f['trip_id'] as int?;
      final ref = (f['booking_reference'] as String?)?.trim() ?? '';
      final conf = (f['confirmation_number'] as String?)?.trim() ?? '';
      tickets.add(Ticket(
        kind: 'flight',
        id: f['id'] as int,
        tripId: tripId,
        tripName: tripId == null ? 'No trip' : (tripNames[tripId] ?? 'Trip'),
        when: DateTime.tryParse(f['departure'] as String? ?? '') ?? DateTime.now(),
        title: '${(f['airline'] as String?) ?? 'Flight'} ${(f['flight_number'] as String?) ?? ''}'.trim(),
        subtitle: '${f['from_city']} → ${f['to_city']}',
        reference: ref.isNotEmpty ? ref : conf,
        extras: [
          if ((f['seat'] as String?)?.isNotEmpty ?? false) ('Seat', f['seat'] as String),
          if ((f['departure_gate'] as String?)?.isNotEmpty ?? false) ('Gate', f['departure_gate'] as String),
          if ((f['departure_terminal'] as String?)?.isNotEmpty ?? false) ('Terminal', f['departure_terminal'] as String),
          ('Status', _flightStatus((f['status'] as String?) ?? '')),
          if ((f['cost'] as num?) != null && (f['cost'] as num) > 0)
            ('Cost', '\$${(f['cost'] as num).toStringAsFixed(0)} ${f['currency'] ?? ''}'),
        ],
      ));
    }

    for (final h in hotels) {
      final tripId = h['trip_id'] as int?;
      final conf = (h['confirmation_number'] as String?)?.trim() ?? '';
      tickets.add(Ticket(
        kind: 'hotel',
        id: h['id'] as int,
        tripId: tripId,
        tripName: tripId == null ? 'No trip' : (tripNames[tripId] ?? 'Trip'),
        when: DateTime.tryParse(h['check_in'] as String? ?? '') ?? DateTime.now(),
        title: (h['name'] as String?) ?? 'Hotel',
        subtitle: '${h['city']} • ${DateFormat('MMM d').format(DateTime.tryParse(h['check_in'] as String? ?? '') ?? DateTime.now())} – ${DateFormat('MMM d, y').format(DateTime.tryParse(h['check_out'] as String? ?? '') ?? DateTime.now())}',
        reference: conf,
        extras: [
          if ((h['phone'] as String?)?.isNotEmpty ?? false) ('Phone', h['phone'] as String),
          if ((h['address'] as String?)?.isNotEmpty ?? false) ('Address', h['address'] as String),
          if ((h['cost'] as num?) != null && (h['cost'] as num) > 0)
            ('Cost', '\$${(h['cost'] as num).toStringAsFixed(0)} ${h['currency'] ?? ''}'),
        ],
      ));
    }

    tickets.sort((a, b) => a.when.compareTo(b.when));

    if (!mounted) return;
    setState(() {
      _tickets = tickets;
      _isLoading = false;
    });
  }

  String _flightStatus(String s) => switch (s.toUpperCase()) {
        'CONFIRMED' => 'Confirmed',
        'BOARDING' => 'Boarding',
        'DEPARTED' => 'Departed',
        'ARRIVED' => 'Arrived',
        'DELAYED' => 'Delayed',
        'CANCELLED' => 'Cancelled',
        _ => 'Confirmed',
      };

  List<Ticket> get _visible => switch (_filter) {
        'flight' => _tickets.where((t) => t.kind == 'flight').toList(),
        'hotel' => _tickets.where((t) => t.kind == 'hotel').toList(),
        'missing' => _tickets.where((t) => t.reference.isEmpty).toList(),
        _ => _tickets,
      };

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied: $value')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;
    final missingCount = _tickets.where((t) => t.reference.isEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tickets', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _filterBar(cs, missingCount),
                Expanded(
                  child: visible.isEmpty
                      ? _empty(cs)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                            itemCount: visible.length,
                            itemBuilder: (c, i) => _ticketCard(visible[i], cs),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterBar(ColorScheme cs, int missingCount) {
    final options = <(String, String, IconData)>[
      ('all', 'All (${_tickets.length})', Icons.confirmation_number_outlined),
      ('flight', 'Flights (${_tickets.where((t) => t.kind == 'flight').length})', Icons.flight),
      ('hotel', 'Hotels (${_tickets.where((t) => t.kind == 'hotel').length})', Icons.hotel),
      if (missingCount > 0) ('missing', 'No reference ($missingCount)', Icons.error_outline),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (value, label, icon) in options)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  avatar: Icon(icon, size: 15),
                  selected: _filter == value,
                  onSelected: (_) => setState(() => _filter = value),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) {
    final msg = switch (_filter) {
      'flight' => 'No flights booked yet. Add one from the Planner tab.',
      'hotel' => 'No hotels booked yet. Add one from the Planner tab.',
      'missing' => 'Everything has a booking reference.',
      _ => 'No tickets yet. Add flights and hotels from the Planner tab and they will collect here.',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.confirmation_number_outlined, size: 56, color: cs.onSurface.withValues(alpha: 0.25)),
            const SizedBox(height: 14),
            Text(msg, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _ticketCard(Ticket t, ColorScheme cs) {
    final isFlight = t.kind == 'flight';
    final color = isFlight ? Colors.purple : Colors.indigo;
    final hasRef = t.reference.isNotEmpty;
    final daysAway = t.when.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(isFlight ? Icons.flight : Icons.hotel, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(t.subtitle, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.65))),
                    ],
                  ),
                ),
                if (daysAway >= 0 && daysAway <= 14)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(
                      daysAway == 0 ? 'Today' : '${daysAway}d',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Booking reference — the whole point of this screen.
            InkWell(
              onTap: hasRef ? () => _copy(t.reference, isFlight ? 'Booking ref' : 'Confirmation') : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: hasRef ? cs.primary.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasRef ? cs.primary.withValues(alpha: 0.25) : Colors.orange.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasRef ? Icons.confirmation_number : Icons.help_outline,
                      size: 15,
                      color: hasRef ? cs.primary : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: hasRef
                          ? Text(
                              t.reference,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: cs.primary,
                              ),
                            )
                          : Text(
                              'No booking reference recorded',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.orange),
                            ),
                    ),
                    if (hasRef)
                      Icon(Icons.copy, size: 14, color: cs.primary.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),

            if (t.extras.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final (label, value) in t.extras)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$label: ', style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                        Text(value, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.luggage, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 5),
                Text(
                  t.tripName,
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
                const Spacer(),
                Text(
                  DateFormat('EEE d MMM y').format(t.when),
                  style: GoogleFonts.inter(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}