import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/recommendation_service.dart';

class CreateTripDialog extends StatefulWidget {
  final Future<void> Function(Trip) onTripCreated;
  final Trip? initialTrip;

  const CreateTripDialog({
    super.key,
    required this.onTripCreated,
    this.initialTrip,
  });

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _originCountryCtrl = TextEditingController();
  final _destCountryCtrl = TextEditingController();
  final _destLatLngCtrl = TextEditingController();

  DateTime _departure = DateTime.now().add(const Duration(days: 30));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 37));
  int _travelers = 1;
  String _transport = 'flight';
  String _status = 'planning';
  String _tripType = 'friends';
  final _currencyCtrl = TextEditingController(text: 'USD');
  String _baseCurrency = 'USD';
  double _totalBudget = 0;
  String? _destinationImage;
  bool _showPersonal = false;
  bool _showAdvanced = false;

  // Personal fields (shown when user opts in)
  String _flightType = 'round_trip';
  String _flightClass = 'economy';
  String _accommodationType = 'hotel';

  static const _countries = [
    'AF','AL','DZ','AD','AO','AG','AR','AM','AU','AT','AZ','BS','BH','BD','BB','BY','BE','BZ','BJ','BT',
    'BO','BA','BW','BR','BN','BG','BF','BI','CV','KH','CM','CA','CF','TD','CL','CN','CO','KM','CG','CD',
    'CR','HR','CU','CY','CZ','DK','DJ','DM','DO','EC','EG','SV','GQ','ER','EE','SZ','ET','FJ','FI','FR',
    'GA','GM','GE','DE','GH','GR','GD','GT','GN','GY','HT','HN','HU','IS','IN','ID','IR','IQ','IE','IL',
    'IT','JM','JP','JO','KZ','KE','KI','KW','KG','LA','LV','LB','LS','LR','LY','LI','LT','LU','MG','MW',
    'MY','MV','ML','MT','MH','MR','MU','MX','FM','MD','MC','MN','ME','MA','MZ','MM','NA','NR','NP','NL',
    'NZ','NI','NE','NG','MK','NO','OM','PK','PW','PA','PG','PY','PE','PH','PL','PT','QA','RO','RU','RW',
    'KN','LC','VC','WS','SM','ST','SA','SN','RS','SC','SL','SG','SK','SI','SB','SO','ZA','KR','SS','ES',
    'LK','SD','SR','SE','CH','SY','TW','TJ','TZ','TH','TL','TG','TO','TT','TN','TR','TM','TV','UG','UA',
    'AE','GB','US','UY','UZ','VU','VE','VN','YE','ZM','ZW',
  ];

  @override
  void initState() {
    super.initState();
    final trip = widget.initialTrip;
    if (trip == null) return;

    _nameCtrl.text = trip.name;
    _originCtrl.text = trip.originName == 'Unknown' ? '' : trip.originName;
    _destCtrl.text = trip.destName == 'Unknown' ? '' : trip.destName;
    _originCountryCtrl.text = trip.originCountry == 'Unknown' ? '' : trip.originCountry;
    _destCountryCtrl.text = trip.destCountry == 'Unknown' ? '' : trip.destCountry;
    _destLatLngCtrl.text = trip.destinationImage ?? '';
    _departure = trip.departure;
    _returnDate = trip.returnDate;
    _travelers = trip.travelers;
    _transport = trip.transport;
    _status = trip.status.toLowerCase();
    _tripType = trip.tripType;
    _baseCurrency = trip.baseCurrency.toUpperCase();
    _currencyCtrl.text = _baseCurrency;
    _totalBudget = trip.totalBudget;
    _destinationImage = trip.destinationImage;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _originCountryCtrl.dispose();
    _destCountryCtrl.dispose();
    _destLatLngCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: kIsWeb ? 16 : MediaQuery.of(context).padding.top + 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.initialTrip == null ? 'New Trip' : 'Edit Trip',
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Personal info toggle
                InkWell(
                  onTap: () => setState(() => _showPersonal = !_showPersonal),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showPersonal ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Personal Information',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _showPersonal ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Icon(
                          _showPersonal ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showPersonal) ...[
                  const SizedBox(height: 12),
                  _buildPersonalFields(colorScheme),
                  const SizedBox(height: 8),
                ],
                // Trip name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Trip Name',
                    hintText: 'Summer Japan Adventure',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.label_outline),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  style: GoogleFonts.inter(fontSize: 14),
                  validator: (v) => v == null || v.isEmpty ? 'Trip name is required' : null,
                ),
                const SizedBox(height: 12),
                // Destination + origin row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _originCtrl,
                        decoration: InputDecoration(
                          labelText: 'From (City)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.flight_takeoff),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _destCtrl,
                        decoration: InputDecoration(
                          labelText: 'To (City)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.flight_land),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Countries row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _originCountryCtrl.text.isEmpty ? null : _originCountryCtrl.text,
                        decoration: InputDecoration(
                          labelText: 'Origin Country',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                        onChanged: (v) {
                          if (v != null) _originCountryCtrl.text = v;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _destCountryCtrl.text.isEmpty ? null : _destCountryCtrl.text,
                        decoration: InputDecoration(
                          labelText: 'Destination Country',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                        onChanged: (v) {
                          if (v != null) _destCountryCtrl.text = v;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Currency
                DropdownButtonFormField<String>(
                  initialValue: _baseCurrency,
                  decoration: InputDecoration(
                    labelText: 'Base Currency',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.attach_money),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  items: const ['AED', 'USD', 'EUR', 'GBP', 'SAR', 'INR', 'UZS', 'JPY', 'AUD', 'CAD']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _baseCurrency = v;
                        _currencyCtrl.text = v;
                      });
                    }
                  },
                  validator: (v) => v == null || v.isEmpty ? 'Currency is required' : null,
                ),
                const SizedBox(height: 12),
                // Dates
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: _departure, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime.now().add(const Duration(days: 730)));
                          if (d != null) setState(() => _departure = d);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: InputContainer(
                          label: 'Departure',
                          icon: Icons.flight_takeoff,
                          child: Text(DateFormat('MMM d, y').format(_departure), style: GoogleFonts.inter(fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: _returnDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                          if (d != null) setState(() => _returnDate = d);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: InputContainer(
                          label: 'Return',
                          icon: Icons.flight_land,
                          child: Text(DateFormat('MMM d, y').format(_returnDate), style: GoogleFonts.inter(fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Travelers + Transport row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Text('👥', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _travelers,
                              decoration: InputDecoration(
                                labelText: 'Travelers',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              ),
                              items: List.generate(10, (i) => i + 1).map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _travelers = v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _transport,
                        decoration: InputDecoration(
                          labelText: 'Transport',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        items: [
                          DropdownMenuItem(value: 'flight', child: Text('✈️ Flight', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'train', child: Text('🚄 Train', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'car', child: Text('🚗 Car', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'bus', child: Text('🚌 Bus', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'boat', child: Text('🚢 Boat', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'cruise', child: Text('🛳️ Cruise', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'bike', child: Text('🚲 Bike', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'walk', child: Text('🚶 Walk', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'cabin', child: Text('🏕️ Cabin', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'rv', child: Text('🚐 RV', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'taxi', child: Text('🚕 Taxi', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'ride', child: Text('🚘 Ride', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'motorbike', child: Text('🏍️ Motorbike', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'van', child: Text('🚐 Van', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'yacht', child: Text('⛵ Yacht', style: GoogleFonts.inter(fontSize: 13))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _transport = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status + Budget row
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        items: [
                          DropdownMenuItem(value: 'idea', child: Text('💡 Idea', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'planning', child: Text('📋 Planning', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'ready', child: Text('🟢 Ready', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'active', child: Text('✅ Active', style: GoogleFonts.inter(fontSize: 13))),
                          DropdownMenuItem(value: 'completed', child: Text('🏁 Completed', style: GoogleFonts.inter(fontSize: 13))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _status = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _totalBudget > 0 ? _totalBudget.toStringAsFixed(2) : '',
                        decoration: InputDecoration(
                          labelText: 'Budget (optional)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.attach_money),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 14),
                        onChanged: (v) {
                          setState(() {
                            _totalBudget = double.tryParse(v) ?? 0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Trip vibe (drives recommendations)
                DropdownButtonFormField<String>(
                  initialValue: _tripType,
                  decoration: InputDecoration(
                    labelText: 'Trip type',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.groups_outlined),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  items: kTripTypes.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _tripType = v);
                  },
                ),
                const SizedBox(height: 12),
                // Destination Image URL
                TextFormField(
                  controller: _destLatLngCtrl,
                  decoration: InputDecoration(
                    labelText: 'Destination Image URL (optional)',
                    hintText: 'https://... (unsplash source)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.image),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  style: GoogleFonts.inter(fontSize: 13),
                  onChanged: (_) {},
                ),
                const SizedBox(height: 16),
                // Advanced toggle
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced ? Icons.visibility : Icons.visibility_off,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Advanced Options',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _showAdvanced ? colorScheme.onSurface : colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        Icon(
                          _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _flightType,
                          decoration: InputDecoration(
                            labelText: 'Flight Type',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                          items: [
                            DropdownMenuItem(value: 'round_trip', child: Text('Round Trip', style: GoogleFonts.inter(fontSize: 13))),
                            DropdownMenuItem(value: 'one_way', child: Text('One Way', style: GoogleFonts.inter(fontSize: 13))),
                            DropdownMenuItem(value: 'multi_city', child: Text('Multi-City', style: GoogleFonts.inter(fontSize: 13))),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _flightType = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _flightClass,
                          decoration: InputDecoration(
                            labelText: 'Class',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                          items: [
                            DropdownMenuItem(value: 'economy', child: Text('Economy', style: GoogleFonts.inter(fontSize: 13))),
                            DropdownMenuItem(value: 'premium', child: Text('Premium', style: GoogleFonts.inter(fontSize: 13))),
                            DropdownMenuItem(value: 'business', child: Text('Business', style: GoogleFonts.inter(fontSize: 13))),
                            DropdownMenuItem(value: 'first', child: Text('First', style: GoogleFonts.inter(fontSize: 13))),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _flightClass = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _accommodationType,
                    decoration: InputDecoration(
                      labelText: 'Accommodation Type',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    items: [
                      DropdownMenuItem(value: 'hotel', child: Text('Hotel', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'hostel', child: Text('Hostel', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'airbnb', child: Text('Airbnb', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'resort', child: Text('Resort', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'guesthouse', child: Text('Guesthouse', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'camping', child: Text('Camping', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'cruise', child: Text('Cruise', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'rv', child: Text('RV', style: GoogleFonts.inter(fontSize: 13))),
                      DropdownMenuItem(value: 'rental', child: Text('Rental', style: GoogleFonts.inter(fontSize: 13))),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _accommodationType = v);
                    },
                  ),
                ],
                const SizedBox(height: 20),
                // Save button
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    widget.initialTrip == null ? 'Save Trip' : 'Update Trip',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalFields(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _flightType,
                decoration: InputDecoration(
                  labelText: 'Flight Type',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                items: [
                  DropdownMenuItem(value: 'round_trip', child: Text('Round Trip', style: GoogleFonts.inter(fontSize: 13))),
                  DropdownMenuItem(value: 'one_way', child: Text('One Way', style: GoogleFonts.inter(fontSize: 13))),
                  DropdownMenuItem(value: 'multi_city', child: Text('Multi-City', style: GoogleFonts.inter(fontSize: 13))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _flightType = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _flightClass,
                decoration: InputDecoration(
                  labelText: 'Class',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                items: [
                  DropdownMenuItem(value: 'economy', child: Text('Economy', style: GoogleFonts.inter(fontSize: 13))),
                  DropdownMenuItem(value: 'premium', child: Text('Premium', style: GoogleFonts.inter(fontSize: 13))),
                  DropdownMenuItem(value: 'business', child: Text('Business', style: GoogleFonts.inter(fontSize: 13))),
                  DropdownMenuItem(value: 'first', child: Text('First', style: GoogleFonts.inter(fontSize: 13))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _flightClass = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _accommodationType,
          decoration: InputDecoration(
            labelText: 'Accommodation Type',
            border: const OutlineInputBorder(),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ),
          items: [
            DropdownMenuItem(value: 'hotel', child: Text('Hotel', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'hostel', child: Text('Hostel', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'airbnb', child: Text('Airbnb', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'resort', child: Text('Resort', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'guesthouse', child: Text('Guesthouse', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'camping', child: Text('Camping', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'cruise', child: Text('Cruise', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'rv', child: Text('RV', style: GoogleFonts.inter(fontSize: 13))),
            DropdownMenuItem(value: 'rental', child: Text('Rental', style: GoogleFonts.inter(fontSize: 13))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _accommodationType = v);
          },
        ),
      ],
    );
  }

  String _transportLabel(String t) {
    switch (t) {
      case 'flight': return '✈️ Flight';
      case 'train': return '🚄 Train';
      case 'car': return '🚗 Car';
      case 'bus': return '🚌 Bus';
      case 'boat': return '🚢 Boat';
      case 'cruise': return '🛳️ Cruise';
      case 'bike': return '🚲 Bike';
      case 'walk': return '🚶 Walk';
      case 'cabin': return '🏕️ Cabin';
      case 'rv': return '🚐 RV';
      case 'taxi': return '🚕 Taxi';
      case 'ride': return '🚘 Ride';
      case 'motorbike': return '🏍️ Motorbike';
      case 'van': return '🚐 Van';
      case 'yacht': return '⛵ Yacht';
      default: return 'Flight';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final origin = _originCtrl.text.trim();
    final dest = _destCtrl.text.trim();
    final originCountry = _originCountryCtrl.text.trim();
    final destCountry = _destCountryCtrl.text.trim();

    if (name.isEmpty) return;

    final trip = Trip(
      name: name,
      originName: origin.isEmpty ? 'Unknown' : origin,
      destName: dest.isEmpty ? 'Unknown' : dest,
      destinationImage: _destLatLngCtrl.text.trim().isNotEmpty
          ? _destLatLngCtrl.text.trim()
          : (_destinationImage ?? _buildFallbackImage()),
      originCountry: originCountry.isEmpty ? 'Unknown' : originCountry,
      destCountry: destCountry.isEmpty ? 'Unknown' : destCountry,
      departure: _departure,
      returnDate: _returnDate,
      travelers: _travelers,
      transport: _transport,
      transportLabel: _transportLabel(_transport),
      status: _status,
      tripType: _tripType,
      baseCurrency: _baseCurrency,
      totalBudget: _totalBudget,
      personalInfo: _showPersonal
          ? PersonalInfo(
              flightType: _flightType,
              flightClass: _flightClass,
              accommodationType: _accommodationType,
            )
          : null,
    );

    await widget.onTripCreated(trip);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(widget.initialTrip == null ? 'Trip Created' : 'Trip Updated'),
        content: Text('"${trip.name}" has been saved.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Deterministic Unsplash image per destination. Falls back to a generic
  /// city photo so a trip always has something to show.
  String _buildFallbackImage() {
    final name = _destCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    const hashes = <String, String>{
      'tokyo': '1540959733-f16614c8edf0',
      'paris': '1502602898657-3e91760cbb34',
      'london': '1513635269975-57669614be8c',
      'dubai': '1583417319058-ip5a242c7b47',
      'new-york': '1496442226666-8d4d0e62e6e9',
      'bangkok': '1508009379798-6350f4b0c0a2',
      'singapore': '1566403303480-66d178c50455',
      'istanbul': '1529274662728-490d81076687',
      'sydney': '1506973320985-6a0f6ea6d0b9',
      'barcelona': '1539037116277-4db20889f2d6',
      'tashkent': '1548013146-3e4e748b234b',
      'samarkand': '1548013146-3e4e748b234b',
      'khiva': '1548013146-3e4e748b234b',
    };
    final key = name.isEmpty ? 'paris' : (hashes[name] != null ? name : _cityKey(name));
    final id = hashes[key] ?? hashes['paris']!;
    return 'https://images.unsplash.com/photo-$id?w=800&q=80';
  }

  /// Matches 'new-york' style keys, falling back to the first word.
  String _cityKey(String slug) {
    final first = slug.split('-').first;
    return first.isEmpty ? 'paris' : first;
  }

}

class InputContainer extends StatelessWidget {
  final String label;
  final IconData icon;
  final Widget child;
  const InputContainer({super.key, required this.label, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withValues(alpha: 0.5), size: 16),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}
