import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import '../services/recommendation_service.dart';

/// Suggests things to do based on destination, date, time of day,
/// trip vibe and group size.
class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});

  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true;

  int? _tripId;
  String _timeOfDay = 'morning';
  String _season = 'any';
  int _maxCost = 0;
  String _ageFilter = 'any';

  List<RankedIdea> _results = const [];
  bool _hasSearched = false;

  final _service = const RecommendationService();

  static const _timeOptions = [
    ('morning', 'Morning', Icons.wb_twilight),
    ('afternoon', 'Afternoon', Icons.wb_sunny),
    ('evening', 'Evening', Icons.wb_shade),
    ('night', 'Night', Icons.nightlight_round),
  ];

  static const _seasonOptions = [
    ('any', 'Any season'),
    ('spring', 'Spring'),
    ('summer', 'Summer'),
    ('autumn', 'Autumn'),
    ('winter', 'Winter'),
  ];

  static const _ageOptions = [
    ('any', 'Everyone'),
    ('family', 'Family friendly only'),
    ('adult', 'Allow 18+'),
  ];

  static const _costOptions = [
    (0, 'Any budget'),
    (20, 'Under \$20'),
    (50, 'Under \$50'),
    (120, 'Under \$120'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final db = await DatabaseHelper().database;
    final rows = await db.query('trips', orderBy: 'departure ASC');
    if (!mounted) return;
    setState(() {
      _trips = rows.map((m) => Trip.fromMap(m)).toList();
      _tripId ??= _trips.isNotEmpty ? _trips.first.id : null;
      _isLoading = false;
    });
  }

  Trip? get _trip {
    if (_tripId == null) return null;
    for (final t in _trips) {
      if (t.id == _tripId) return t;
    }
    return null;
  }

  void _search() {
    final trip = _trip;
    if (trip == null) return;
    final results = _service.recommend(
      RecommendationQuery(
        destination: '${trip.destName} ${trip.destCountry}',
        when: trip.departure,
        timeOfDay: _timeOfDay,
        tripType: trip.tripType,
        travellers: trip.travelers,
        season: _season,
        maxCostUsd: _maxCost,
        ageFilter: _ageFilter,
      ),
      limit: 30,
    );
    setState(() {
      _results = results;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = _trip;

    return Scaffold(
      appBar: AppBar(title: Text('Recommendations', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trips.isEmpty
              ? _noTrips(cs)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    _sectionLabel('Trip', Icons.luggage_outlined, cs),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _tripId,
                      decoration: _inputDecoration('Choose a trip', cs),
                      items: _trips
                          .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} — ${t.destName}', overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (v) => setState(() => _tripId = v),
                    ),
                    if (trip != null) _tripContextCard(trip, cs),
                    const SizedBox(height: 20),
                    _sectionLabel('When', Icons.schedule, cs),
                    const SizedBox(height: 8),
                    _timePicker(cs),
                    const SizedBox(height: 16),
                    _seasonPicker(cs),
                    const SizedBox(height: 20),
                    _sectionLabel('Who it is for', Icons.groups_outlined, cs),
                    const SizedBox(height: 8),
                    _agePicker(cs),
                    const SizedBox(height: 20),
                    _sectionLabel('Budget', Icons.account_balance_wallet_outlined, cs),
                    const SizedBox(height: 8),
                    _costPicker(cs),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: trip == null ? null : _search,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Get recommendations'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_hasSearched) _resultsSection(cs),
                  ],
                ),
    );
  }

  Widget _noTrips(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 64, color: cs.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No trips yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Create a trip first — recommendations are tailored to its destination, dates and group.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripContextCard(Trip trip, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _pill(Icons.place, trip.destName, cs),
          _pill(Icons.people_outline, '${trip.travelers} traveller${trip.travelers == 1 ? '' : 's'}', cs),
          _pill(Icons.groups_outlined, kTripTypes[trip.tripType] ?? trip.tripType, cs),
          _pill(Icons.calendar_today, DateFormat('MMM d, y').format(trip.departure), cs),
          _pill(seasonIcon(_season == 'any' ? seasonOf(trip.departure) : _season), _season == 'any' ? seasonOf(trip.departure) : _season, cs),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(text, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _timePicker(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label, icon) in _timeOptions)
          ChoiceChip(
            label: Text(label),
            avatar: Icon(icon, size: 16, color: _timeOfDay == value ? cs.onPrimary : cs.onSurface),
            selected: _timeOfDay == value,
            onSelected: (_) => setState(() => _timeOfDay = value),
          ),
      ],
    );
  }

  Widget _seasonPicker(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in _seasonOptions)
          ChoiceChip(
            label: Text(label),
            selected: _season == value,
            onSelected: (_) => setState(() => _season = value),
          ),
      ],
    );
  }

  Widget _agePicker(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in _ageOptions)
          ChoiceChip(
            label: Text(label),
            selected: _ageFilter == value,
            onSelected: (_) => setState(() => _ageFilter = value),
          ),
      ],
    );
  }

  Widget _costPicker(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in _costOptions)
          ChoiceChip(
            label: Text(label),
            selected: _maxCost == value,
            onSelected: (_) => setState(() => _maxCost = value),
          ),
      ],
    );
  }

  Widget _resultsSection(ColorScheme cs) {
    if (_results.isEmpty) {
      return Column(
        children: [
          const SizedBox(height: 20),
          Text('No matches for those filters.', style: GoogleFonts.inter(color: cs.onSurface.withValues(alpha: 0.6))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('${_results.length} ideas', Icons.lightbulb_outline, cs),
        const SizedBox(height: 12),
        ..._results.map((r) => _ideaCard(r, cs)),
      ],
    );
  }

  Widget _ideaCard(RankedIdea ranked, ColorScheme cs) {
    final idea = ranked.idea;
    final costLabel = idea.costUsd == 0 ? 'Free' : '\$${idea.costUsd}';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: categoryColor(idea.category).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(categoryIcon(idea.category), color: categoryColor(idea.category), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(idea.title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '${idea.category} • ${_durationLabel(idea.minutes)} • $costLabel',
                        style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(height: 6),
                      _ageBadge(idea.ageRating, cs),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(idea.blurb, style: GoogleFonts.inter(fontSize: 13, height: 1.4, color: cs.onSurface.withValues(alpha: 0.8))),
            if (ranked.reasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final reason in ranked.reasons)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(reason, style: GoogleFonts.inter(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w500)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ageBadge(String rating, ColorScheme cs) {
    final isAdult = rating == 'adult';
    final isTeen = rating == 'teen';
    final label = kAgeRatings[rating] ?? rating;
    final color = isAdult ? Colors.orange : (isTeen ? Colors.blue : Colors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdult ? Icons.no_adult_content : (isTeen ? Icons.groups_2_outlined : Icons.family_restroom),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surface.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  IconData seasonIcon(String season) => switch (season) {
        'spring' => Icons.local_florist,
        'summer' => Icons.beach_access,
        'autumn' => Icons.emoji_nature,
        _ => Icons.ac_unit,
      };
}

Color categoryColor(String category) => switch (category) {
      'Food' => Colors.orange,
      'Culture' => Colors.indigo,
      'Nature' => Colors.green,
      'Relax' => Colors.teal,
      'Shopping' => Colors.pink,
      'Sightseeing' => Colors.blue,
      'Nightlife' => Colors.purple,
      'Sport' => Colors.red,
      'Business' => Colors.blueGrey,
      _ => Colors.grey,
    };

IconData categoryIcon(String category) => switch (category) {
      'Food' => Icons.restaurant,
      'Culture' => Icons.account_balance,
      'Nature' => Icons.park,
      'Relax' => Icons.spa,
      'Shopping' => Icons.shopping_bag,
      'Sightseeing' => Icons.photo_camera,
      'Nightlife' => Icons.nightlife,
      'Sport' => Icons.sports_soccer,
      'Business' => Icons.business_center,
      _ => Icons.explore,
    };
