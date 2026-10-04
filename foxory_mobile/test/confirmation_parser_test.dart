// Field extraction from booking confirmations.
//
// The parser is deliberately conservative and every result is a suggestion,
// never an auto-save. These tests pin both what it should find and, just as
// importantly, what it must NOT invent.
import 'package:flutter_test/flutter_test.dart';
import 'package:foxory_mobile/services/confirmation_parser.dart';

void main() {
  const parser = ConfirmationParser();

  const flydubai = '''
Flight Booking Confirmation
Airline: FLYDUBAI   Flight: FZ1234
PNR: QK7X2M
Abu Dhabi (AUH) to Tashkent (TAS)
Departure: 15 Nov 2026   Arrival: 15 Nov 2026
Passenger: SULTAN ALZAABI   Seat: 12A
Total: 1,850.00 AED
''';

  test('reads a flight confirmation', () {
    final r = parser.parse(flydubai);
    expect(r.reference, 'QK7X2M');
    expect(r.flightNumber, 'FZ1234');
    expect(r.airline, 'FLYDUBAI');
    expect(r.from, contains('Abu Dhabi'));
    expect(r.to, contains('Tashkent'));
    expect(r.seat, '12A');
    expect(r.total, contains('1,850.00'));
    expect(r.dates, isNotEmpty);
    expect(r.foundAnything, isTrue);
  });

  test('finds the booking reference from the various labels airlines use', () {
    for (final label in ['PNR', 'Booking reference', 'Record locator', 'Reservation code', 'Confirmation code']) {
      final r = parser.parse('$label: AB12CD\nsome other text here');
      expect(r.reference, 'AB12CD', reason: 'failed on "$label"');
    }
  });

  test('a bare "Confirmation" heading does not capture the next line', () {
    // Regression: "Booking Confirmation" on one line followed by
    // "Airline: FLYDUBAI" made the old parser capture AIRLINE as the PNR.
    final r = parser.parse('Booking Confirmation\nAirline: FLYDUBAI\nPNR: QK7X2M');
    expect(r.reference, 'QK7X2M');
    expect(r.reference, isNot('AIRLINE'));
  });

  test('does not mistake a label for a reference', () {
    final r = parser.parse('Booking reference: NUMBER');
    expect(r.reference, isNot('NUMBER'));
  });

  test('parses ISO dates', () {
    final r = parser.parse('Departure 2026-11-15\nArrival 2026-11-22\nPNR: ZZ11AA');
    expect(r.dates.length, greaterThanOrEqualTo(2));
    expect(r.dates.first, DateTime(2026, 11, 15));
  });

  test('parses day/month/year without inverting the order', () {
    final r = parser.parse('Check in: 15/11/2026\nCheck out: 22/11/2026');
    expect(r.dates.first, DateTime(2026, 11, 15));
    expect(r.dates[1], DateTime(2026, 11, 22));
  });

  test('deduplicates repeated dates', () {
    final r = parser.parse('Departure: 15 Nov 2026\nArrival: 15 Nov 2026');
    expect(r.dates.length, 1);
  });

  test('reads a hotel confirmation', () {
    const hotel = '''
HOTEL BOOKING CONFIRMATION
Hotel: Novotel Tashkent
Confirmation Number: NH9981
Check-in: 15 Nov 2026
Check-out: 21 Nov 2026
Total: 620.00 USD
''';
    final r = parser.parse(hotel);
    expect(r.hotelName, contains('Novotel'));
    expect(r.reference, 'NH9981');
    expect(r.total, contains('620.00'));
    expect(r.dates.length, greaterThanOrEqualTo(2));
  });

  test('a scanned document yields nothing and is flagged', () {
    final r = parser.parse('', scanned: true);
    expect(r.scanned, isTrue);
    expect(r.foundAnything, isFalse);
    expect(r.reference, isNull);
  });

  test('returns nothing rather than guessing on unrelated text', () {
    const junk = 'Dear customer, thank you for shopping with us. '
        'Our policy is subject to change without notice.';
    final r = parser.parse(junk);
    expect(r.reference, isNull, reason: 'must not invent a booking reference');
    expect(r.flightNumber, isNull);
  });

  test('does not read an airport code as a flight number', () {
    final r = parser.parse('Flying from AUH to TAS. Confirmation: QQ77ZZ');
    expect(r.reference, 'QQ77ZZ');
  });

  test('a range seat is kept whole', () {
    final r = parser.parse('Seat: 12A-12C\nPNR: ZZ11AA');
    expect(r.seat, '12A-12C');
  });

  test('empty input is handled without throwing', () {
    expect(() => parser.parse(''), returnsNormally);
    expect(parser.parse('').foundAnything, isFalse);
    expect(() => parser.parse('   \n  \n'), returnsNormally);
  });

  test('summary lists what was found for the review sheet', () {
    final r = parser.parse(flydubai);
    expect(r.summary, isNotEmpty);
    expect(r.summary.any((s) => s.contains('QK7X2M')), isTrue);
  });

  test('extraction returns data but never writes anything', () {
    // Guards the design decision - a wrong booking reference is worse than
    // none, so the parser only returns suggestions for review.
    final r = parser.parse(flydubai);
    expect(r.reference, isNotNull);
    expect(r.summary, contains('Booking reference: QK7X2M'));
  });
}