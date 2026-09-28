import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../services/hotel_confirmation_service.dart';

/// Hotel booking entry form — styled to match the Foxory theme:
///   Google Fonts (Inter / Poppins), Material 3 color scheme,
///   card-surface form, rounded inputs with primary focus, themed buttons.

class HotelBookingForm extends StatefulWidget {
  final int? preselectedTripId;

  const HotelBookingForm({super.key, this.preselectedTripId});

  @override
  State<HotelBookingForm> createState() => _HotelBookingFormState();
}

class _HotelBookingFormState extends State<HotelBookingForm> {
  final _form = {
    'name': TextEditingController(),
    'address': TextEditingController(),
    'city': TextEditingController(),
    'country': TextEditingController(),
    'confirmation': TextEditingController(),
    'url': TextEditingController(),
    'phone': TextEditingController(),
    'cost': TextEditingController(),
  };
  DateTime? _checkIn;
  DateTime? _checkOut;
  String _currency = 'USD';
  int? _selectedTripId;
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selectedTripId = widget.preselectedTripId;
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    final db = await DatabaseHelper().database;
    final trips = await db.query('trips', orderBy: 'departure DESC');
    setState(() => _trips = trips);
  }

  @override
  void dispose() {
    for (final c in _form.values) c.dispose();
    super.dispose();
  }

  void _pickDate(String which) {
    final initial = which == 'in' ? (_checkIn ?? DateTime.now()) : (_checkOut ?? _checkIn ?? DateTime.now());
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1095)),
    ).then((d) {
      if (d == null) return;
      setState(() {
        if (which == 'in') _checkIn = d;
        else _checkOut = d;
      });
    });
  }

  Future<void> _save() async {
    if (_form['name']!.text.trim().isEmpty) {
      setState(() => _saveError = 'Hotel name is required.'); return;
    }
    if (_checkIn == null) { setState(() => _saveError = 'Check-in date is required.'); return; }
    if (_selectedTripId == null) { setState(() => _saveError = 'Please select a trip.'); return; }

    setState(() { _isLoading = true; _saveError = null; });

    try {
      final db = await DatabaseHelper().database;
      final data = <String, dynamic>{
        'trip_id': _selectedTripId,
        'name': _form['name']!.text.trim(),
        'address': _form['address']!.text.trim(),
        'city': _form['city']!.text.trim(),
        'country': _form['country']!.text.trim(),
        'check_in': _checkIn!.toIso8601String(),
        'check_out': (_checkOut ?? _checkIn!.add(const Duration(days: 1))).toIso8601String(),
        'cost': double.tryParse(_form['cost']!.text.replaceAll(',', '')) ?? 0,
        'currency': _currency,
        'confirmation_number': _form['confirmation']!.text.trim().toUpperCase(),
        'phone': _form['phone']!.text.trim(),
        'website': _form['url']!.text.trim(),
        'booking_url': _form['url']!.text.trim(),
        'notes': '',
        'bookmarked': 0,
        'rating': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'sync_enabled': 1,
        'sync_status': 0,
      };
      final id = await db.insert('hotels', data, conflictAlgorithm: ConflictAlgorithm.replace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hotel saved — ${_form['name']!.text.trim()} (#$id)')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _saveError = 'Save failed: $e';
      }
    }
  }

  Future<void> _autoMatch() async {
    final city = _form['city']!.text.trim();
    if (city.isEmpty || _checkIn == null) return;
    final tripId = await findMatchingTrip(
      city: city,
      checkIn: _checkIn!,
      checkOut: _checkOut ?? _checkIn!.add(const Duration(days: 1)),
      tripQuery: () async => (await DatabaseHelper().database).query('trips', orderBy: 'departure DESC'),
    );
    if (tripId != null && mounted) {
      setState(() => _selectedTripId = tripId);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon, {bool required = false}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: required ? '$label *' : label,
      prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.5)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
    );
  }

  Widget _dateField(String label, IconData icon, {required String which}) {
    final cs = Theme.of(context).colorScheme;
    final value = which == 'in' ? _checkIn : _checkOut;
    return InkWell(
      onTap: () => _pickDate(which),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: cs.onSurface.withOpacity(0.5)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: cs.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
        ),
        child: Text(
          value != null ? DateFormat('MMM d, y').format(value) : ' tap to set',
          style: value == null
              ? GoogleFonts.inter(fontSize: 14, color: cs.onSurface.withOpacity(0.4))
              : GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _currencyDropdown() {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      value: _currency,
      decoration: InputDecoration(
        labelText: 'Currency',
        prefixIcon: Icon(Icons.attach_money, size: 20, color: cs.onSurface.withOpacity(0.5)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withOpacity(0.4),
      ),
      items: const ['USD','EUR','GBP','AED','INR','CHF','CAD','AUD','THB','SGD','JPY']
          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 14))))
          .toList(),
      onChanged: (v) => setState(() => _currency = v ?? 'USD'),
      style: GoogleFonts.inter(fontSize: 14),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        title: Text(
          'Add Hotel Booking',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _trips.isNotEmpty ? _autoMatch : null,
            child: Text(
              'Auto-match trip',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: cs.primary),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _saveError != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Text(
                      _saveError!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card surface for the form
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant.withOpacity(0.15)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ---- Stay details ----
                              _sectionHeader('Stay details', Icons.hotel),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _form['name'],
                                decoration: _inputDecoration('Hotel name', Icons.hotel, required: true),
                                autofocus: true,
                                style: GoogleFonts.inter(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _form['address'],
                                decoration: _inputDecoration('Address', Icons.location_on),
                                style: GoogleFonts.inter(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _form['city'],
                                      decoration: _inputDecoration('City', Icons.location_city),
                                      onChanged: (_) => _autoMatch(),
                                      style: GoogleFonts.inter(fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextField(
                                      controller: _form['country'],
                                      decoration: _inputDecoration('Country', Icons.public),
                                      style: GoogleFonts.inter(fontSize: 15),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateField('Check-in', Icons.calendar_today, which: 'in'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _dateField('Check-out', Icons.calendar_today, which: 'out'),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              // ---- Confirmation details ----
                              _sectionHeader('Confirmation details', Icons.badge),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _form['confirmation'],
                                decoration: _inputDecoration('Confirmation #', Icons.badge),
                                style: GoogleFonts.inter(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _form['cost'],
                                      decoration: _inputDecoration('Total cost', Icons.attach_money),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.inter(fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _currencyDropdown(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _form['url'],
                                decoration: _inputDecoration('Booking URL', Icons.link),
                                keyboardType: TextInputType.url,
                                style: GoogleFonts.inter(fontSize: 15),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _form['phone'],
                                decoration: _inputDecoration('Phone', Icons.phone),
                                style: GoogleFonts.inter(fontSize: 15),
                              ),

                              const SizedBox(height: 20),
                              // ---- Linked trip ----
                              _sectionHeader('Link to trip', Icons.flight),
                              const SizedBox(height: 12),
                              if (_trips.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 16, color: cs.onSurface.withOpacity(0.5)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'No trips yet. Create a trip first, then come back.',
                                        style: GoogleFonts.inter(fontSize: 13, color: cs.onSurface.withOpacity(0.6)),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...(_trips.map((t) => RadioListTile<int>(
                                  value: t['id'] as int,
                                  groupValue: _selectedTripId,
                                  title: Text(
                                    '${t['name']} — ${t['dest_name']}',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  subtitle: Text(
                                    '${DateFormat('MMM d, y').format(DateTime.tryParse(t['departure'] as String ?? '') ?? DateTime.now())} → ${DateFormat('MMM d, y').format(DateTime.tryParse(t['return_date'] as String ?? '') ?? DateTime.now())}',
                                    style: GoogleFonts.inter(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                                  ),
                                  onChanged: (id) => setState(() => _selectedTripId = id),
                                ))),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Action buttons
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Save Hotel Booking',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
    );
  }
}
