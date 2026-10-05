import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/database_helper.dart';
import '../models/models.dart';

/// Compact flight entry used by Quick Capture.
///
/// Written as new code rather than moved out of the planner, so the planner's
/// own form keeps working untouched. [onSaved] lets the caller refresh.
Future<bool> showQuickFlightSheet(
  BuildContext context,
  Trip trip, {
  Future<void> Function()? onSaved,
}) async {
  final tripId = trip.id;
  if (tripId == null) return false;

  final airline = TextEditingController();
  final number = TextEditingController();
  final from = TextEditingController(
    text: trip.originName.trim().toLowerCase() == 'unknown' ? '' : trip.originName,
  );
  final fromCountry = TextEditingController(text: trip.originCountry);
  final to = TextEditingController(
    text: trip.destName.trim().toLowerCase() == 'unknown' ? '' : trip.destName,
  );
  final toCountry = TextEditingController(text: trip.destCountry);
  final seat = TextEditingController();
  final ref = TextEditingController();
  final cost = TextEditingController();

  DateTime departure = trip.departure;
  DateTime arrival = trip.departure;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add flight to ${trip.name}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: airline,
                      decoration: const InputDecoration(labelText: 'Airline', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: number,
                      decoration: const InputDecoration(labelText: 'Flight no.', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: from,
                      decoration: const InputDecoration(labelText: 'From city', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: fromCountry,
                      decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: to,
                      decoration: const InputDecoration(labelText: 'To city', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: toCountry,
                      decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _dateRow(ctx, 'Departure', departure, (d) => setSheet(() {
                departure = d;
                if (arrival.isBefore(d)) arrival = d;
              })),
              const SizedBox(height: 8),
              _dateRow(ctx, 'Arrival', arrival, (d) => setSheet(() => arrival = d)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: seat,
                      decoration: const InputDecoration(labelText: 'Seat', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ref,
                      decoration: const InputDecoration(labelText: 'Booking ref', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cost (${trip.baseCurrency})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final airlineName = airline.text.trim();
                        final flightNo = number.text.trim();
                        final fromCity = from.text.trim();
                        final toCity = to.text.trim();

                        // from_city / to_city / from_country / to_country are all
                        // NOT NULL, so refuse rather than write a broken row.
                        if (airlineName.isEmpty || flightNo.isEmpty || fromCity.isEmpty || toCity.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Airline, flight number, from and to are required')),
                          );
                          return;
                        }

                        final now = DateTime.now().toIso8601String();
                        await DatabaseHelper().insert('flights', {
                          'trip_id': tripId,
                          'airline': airlineName,
                          'flight_number': flightNo,
                          'from_city': fromCity,
                          'from_country': fromCountry.text.trim(),
                          'from_code': null,
                          'to_city': toCity,
                          'to_country': toCountry.text.trim(),
                          'to_code': null,
                          'departure': departure.toIso8601String(),
                          'arrival': arrival.toIso8601String(),
                          'seat': seat.text.trim().isEmpty ? null : seat.text.trim(),
                          'booking_reference': ref.text.trim().isEmpty ? null : ref.text.trim(),
                          'cost': double.tryParse(cost.text.trim()),
                          'currency': trip.baseCurrency,
                          'status': 'CONFIRMED',
                          'notes': '',
                          'bookmarked': 0,
                          'duration_minutes': arrival.difference(departure).inMinutes,
                          'created_at': now,
                          'updated_at': now,
                          'sync_enabled': 1,
                          'sync_status': 0,
                        });

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Save flight'),
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

  if (saved == true) await onSaved?.call();
  return saved == true;
}

Widget _dateRow(
  BuildContext context,
  String label,
  DateTime value,
  ValueChanged<DateTime> onPick,
) {
  return InkWell(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value,
        firstDate: DateTime(2020),
        lastDate: DateTime(2035),
      );
      if (picked != null) onPick(picked);
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: Text(DateFormat('d MMM yyyy').format(value)),
    ),
  );
}
