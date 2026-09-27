import 'package:flutter/material.dart';
import '../models/models.dart';
import '../core/database_helper.dart';
import 'package:intl/intl.dart';

class CreateTripDialog extends StatefulWidget {
  final Function(Trip) onTripCreated;

  const CreateTripDialog({super.key, required this.onTripCreated});

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();
  final _departureCtrl = TextEditingController();
  final _returnCtrl = TextEditingController();

  String _originCountry = 'United Arab Emirates';
  String _destCountry = '';
  double? _originLat;
  double? _originLon;
  double? _destLat;
  double? _destLon;

  int _travelers = 1;
  String _baseCurrency = 'USD';
  String _transportType = 'flight';
  String _status = 'IDEA';

  DateTime _departure = DateTime.now().add(const Duration(days: 30));
  DateTime _returnDate = DateTime.now().add(const Duration(days: 37));

  final bool _autoGeocode = true;


  final List<String> _currencies = [
    'USD', 'EUR', 'GBP', 'AED', 'INR', 'JPY', 'CNY', 'KRW', 'SGD', 'AUD', 'CAD',
  ];

  final List<String> _transportOptions = [
    'flight', 'car', 'train', 'bus', 'boat', 'mixed',
  ];

  final Map<String, String> _transportLabels = {
    'flight': 'Flight',
    'car': 'Road Trip',
    'train': 'Train',
    'bus': 'Bus',
    'boat': 'Cruise/Ferry',
    'mixed': 'Mixed',
  };

  final Map<String, String> _statusLabels = {
    'IDEA': 'Idea',
    'PLANNING': 'Planning',
    'READY': 'Ready',
  };

  @override
  void initState() {
    super.initState();
    _departureCtrl.text = DateFormat('yyyy-MM-dd').format(_departure);
    _returnCtrl.text = DateFormat('yyyy-MM-dd').format(_returnDate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _originCtrl.dispose();
    _destCtrl.dispose();
    _departureCtrl.dispose();
    _returnCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDeparture() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _departure = date;
        _departureCtrl.text = DateFormat('yyyy-MM-dd').format(date);
        // Auto-adjust return date
        if (_returnDate.isBefore(date.add(const Duration(days: 1)))) {
          _returnDate = date.add(const Duration(days: 7));
          _returnCtrl.text = DateFormat('yyyy-MM-dd').format(_returnDate);
        }
      });
    }
  }

  Future<void> _selectReturn() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: _departure.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() {
        _returnDate = date;
        _returnCtrl.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  void _geocodeOrigin() {
    // Simple geocoding simulation - in real app would use GeocodingService
    final query = _originCtrl.text.toLowerCase();
    setState(() {
      if (query.contains('abu dhabi') || query.contains('dubai')) {
        _originLat = 24.4539;
        _originLon = 54.3772;
        _originCountry = 'United Arab Emirates';
      } else if (query.contains('london')) {
        _originLat = 51.5074;
        _originLon = -0.1278;
        _originCountry = 'United Kingdom';
      } else if (query.contains('paris')) {
        _originLat = 48.8566;
        _originLon = 2.3522;
        _originCountry = 'France';
      } else if (query.contains('new york')) {
        _originLat = 40.7128;
        _originLon = -74.0060;
        _originCountry = 'United States';
      } else if (query.contains('tokyo')) {
        _originLat = 35.6762;
        _originLon = 139.6503;
        _originCountry = 'Japan';
      } else if (query.contains('bangkok')) {
        _originLat = 13.7563;
        _originLon = 100.5018;
        _originCountry = 'Thailand';
      } else {
        _originLat = 24.0;
        _originLon = 54.0;
        _originCountry = 'Unknown';
      }
    });
  }

  void _geocodeDestination() {
    final query = _destCtrl.text.toLowerCase();
    setState(() {
      if (query.contains('abu dhabi') || query.contains('dubai')) {
        _destLat = 24.4539;
        _destLon = 54.3772;
        _destCountry = 'United Arab Emirates';
      } else if (query.contains('tashkent')) {
        _destLat = 41.2995;
        _destLon = 69.2401;
        _destCountry = 'Uzbekistan';
      } else if (query.contains('london')) {
        _destLat = 51.5074;
        _destLon = -0.1278;
        _destCountry = 'United Kingdom';
      } else if (query.contains('paris')) {
        _destLat = 48.8566;
        _destLon = 2.3522;
        _destCountry = 'France';
      } else if (query.contains('new york')) {
        _destLat = 40.7128;
        _destLon = -74.0060;
        _destCountry = 'United States';
      } else if (query.contains('tokyo')) {
        _destLat = 35.6762;
        _destLon = 139.6503;
        _destCountry = 'Japan';
      } else if (query.contains('khartoum')) {
        _destLat = 15.5007;
        _destLon = 32.5599;
        _destCountry = 'Sudan';
      } else {
        _destLat = 41.0;
        _destLon = 69.0;
        _destCountry = _destCountry;
      }
    });
  }

  Future<void> _createTrip() async {
    if (!_formKey.currentState!.validate()) return;

    final trip = Trip(
      name: _nameCtrl.text,
      originName: _originCtrl.text,
      originLat: _originLat,
      originLon: _originLon,
      originCountry: _originCountry,
      destName: _destCtrl.text,
      destLat: _destLat,
      destLon: _destLon,
      destCountry: _destCountry.isEmpty ? 'Unknown' : _destCountry,
      departure: _departure,
      returnDate: _returnDate,
      travelers: _travelers,
      baseCurrency: _baseCurrency,
      transportType: _transportType,
      status: _status,
    );

    final db = DatabaseHelper();
    final id = await db.insert('trips', trip.toMap());

    final completeTrip = trip.copyWith(id: id);

    setState(() {});

    widget.onTripCreated(completeTrip);

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create New Trip',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip name
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Trip Name *',
                      hintText: 'e.g., Summer in Europe',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  // Origin
                  TextFormField(
                    controller: _originCtrl,
                    decoration: InputDecoration(
                      labelText: 'Origin *',
                      hintText: 'e.g., Abu Dhabi',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _geocodeOrigin,
                        tooltip: 'Use my location',
                      ),
                    ),
                    onChanged: (v) {
                      if (_autoGeocode) _geocodeOrigin();
                    },
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Country: $_originCountry',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Destination
                  TextFormField(
                    controller: _destCtrl,
                    decoration: InputDecoration(
                      labelText: 'Destination *',
                      hintText: 'e.g., Tashkent',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: _geocodeDestination,
                        tooltip: 'Use my location',
                      ),
                    ),
                    onChanged: (v) {
                      if (_autoGeocode) _geocodeDestination();
                    },
                    validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Country: ${_destCountry.isEmpty ? "Not set" : _destCountry}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _selectDeparture,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Departure *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('MMM d, y').format(_departure)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _selectReturn,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Return *',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(DateFormat('MMM d, y').format(_returnDate)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_departure.difference(DateTime.now()).inDays} days until departure · ${_returnDate.difference(_departure).inDays} nights',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 12),
                  // Travelers + Currency row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _travelers,
                          decoration: const InputDecoration(
                            labelText: 'Travelers',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(10, (i) => i + 1)
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _travelers = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _baseCurrency,
                          decoration: const InputDecoration(
                            labelText: 'Base Currency',
                            border: OutlineInputBorder(),
                          ),
                          items: _currencies.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _baseCurrency = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Transport type
                  DropdownButtonFormField<String>(
                    initialValue: _transportType,
                    decoration: const InputDecoration(
                      labelText: 'Transport Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _transportOptions.map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_transportLabels[t] ?? t),
                        )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _transportType = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Status
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: _statusLabels.entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _createTrip,
                      child: const Text('Create Trip'),
                    ),
                  ),
                  const SizedBox(height: 8),
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
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
