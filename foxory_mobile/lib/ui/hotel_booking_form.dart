import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/database_helper.dart';
import '../services/hotel_confirmation_service.dart';

/// Manual hotel booking entry form.
///
/// A clean form for adding a hotel stay to a trip: hotel name, address, city,
/// country, check-in/out dates, confirmation number, booking URL, phone, cost,
/// currency. The trip is auto-suggested (matching destination city + date
/// overlap) but the user can pick any trip from the list.
///
/// No OCR, no photo parsing — just structured data entry, linked to trips.

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
    // Auto-suggest: if preselected, try to match by city+date
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
      if (which == 'in') {
        setState(() => _checkIn = d);
      } else {
        setState(() => _checkOut = d);
      }
    });
  }

  Future<void> _save() async {
    if (_form['name']!.text.trim().isEmpty) {
      _saveError = 'Hotel name is required.'; return;
    }
    if (_checkIn == null) { _saveError = 'Check-in date is required.'; return; }
    if (_selectedTripId == null) { _saveError = 'Please select a trip.'; return; }

    setState(() { _isLoading = true; _saveError = null; });

    try {
      final db = DatabaseHelper();
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
      final id = await db.insertHotel(data);
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

  /// Try to auto-match a trip by destination city + date overlap.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Hotel Booking'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _trips.isNotEmpty ? _autoMatch : null,
            child: const Text('Auto-match trip'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _saveError != null
              ? Center(child: Text(_saveError!, style: const TextStyle(color: Colors.red)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // basic info
                      TextField(
                        controller: _form['name'],
                        decoration: const InputDecoration(
                          labelText: 'Hotel name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.hotel),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _form['address'],
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _form['city'],
                              decoration: const InputDecoration(
                                labelText: 'City',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              onChanged: (_) => _autoMatch(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _form['country'],
                              decoration: const InputDecoration(
                                labelText: 'Country',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.public),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('in'),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Check-in *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _checkIn != null
                                      ? DateFormat('MMM d, y').format(_checkIn!)
                                      : ' tap to set',
                                  style: _checkIn == null
                                      ? const TextStyle(color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate('out'),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Check-out',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  _checkOut != null
                                      ? DateFormat('MMM d, y').format(_checkOut!)
                                      : (_checkIn != null ? ' tap to set' : ' tap to set'),
                                  style: (_checkOut == null)
                                      ? const TextStyle(color: Colors.grey)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Confirmation details',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _form['confirmation'],
                        decoration: const InputDecoration(
                          labelText: 'Confirmation #',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _form['cost'],
                              decoration: const InputDecoration(
                                labelText: 'Total cost',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _currency,
                              decoration: const InputDecoration(
                                labelText: 'Currency',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                'USD','EUR','GBP','AED','INR','CHF','CAD','AUD','THB','SGD','JPY',
                              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (v) => setState(() => _currency = v ?? 'USD'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _form['url'],
                        decoration: const InputDecoration(
                          labelText: 'Booking URL',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _form['phone'],
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Link to trip *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      if (_trips.isEmpty)
                        const Text(
                          'No trips yet. Create a trip first, then come back.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        )
                      else
                        ...(_trips.map((t) => RadioListTile<int>(
                          value: t['id'] as int,
                          groupValue: _selectedTripId,
                          title: Text('${t['name']} — ${t['dest_name']}'),
                          subtitle: Text(
                            '${DateFormat('MMM d, y').format(DateTime.tryParse(t['departure'] as String ?? '') ?? DateTime.now())} → ${DateFormat('MMM d, y').format(DateTime.tryParse(t['return_date'] as String ?? '') ?? DateTime.now())}'),
                          onChanged: (id) => setState(() => _selectedTripId = id),
                        ))),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Save Hotel Booking'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
