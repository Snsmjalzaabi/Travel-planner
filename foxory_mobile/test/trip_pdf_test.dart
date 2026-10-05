// The PDF is how Sultan gets trip info to his friends, so it has to actually
// produce a valid, readable document - not just compile.
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_test/flutter_test.dart';
import 'package:your_travel_buddy/models/models.dart';
import 'package:your_travel_buddy/services/budget_service.dart';
import 'package:your_travel_buddy/services/currency_service.dart';
import 'package:your_travel_buddy/services/trip_pdf_service.dart';

Trip buildTrip({double budget = 9000, int travelers = 3}) => Trip(
      id: 1,
      name: 'Uzbek',
      originName: 'Abu Dhabi',
      originCountry: 'AE',
      destName: 'Tashkent',
      destCountry: 'UZ',
      departure: DateTime(2026, 11, 15),
      returnDate: DateTime(2026, 11, 21),
      travelers: travelers,
      baseCurrency: 'AED',
      transport: 'flight',
      status: 'planning',
      totalBudget: budget,
      tripType: 'friends',
    );

Flight buildFlight() => Flight(
      id: 1,
      tripId: 1,
      airline: 'FLYDUBAI',
      flightNumber: 'FZ1234',
      fromCity: 'Abu Dhabi',
      fromCountry: 'AE',
      fromCode: 'AUH',
      toCity: 'Tashkent',
      toCountry: 'UZ',
      toCode: 'TAS',
      departure: DateTime(2026, 11, 15, 8, 30),
      arrival: DateTime(2026, 11, 15, 12, 45),
      seat: '12A',
      bookingReference: 'QK7X2M',
      cost: 1850,
      currency: 'AED',
    );

Hotel buildHotel() => Hotel(
      id: 1,
      tripId: 1,
      name: 'Novotel Tashkent',
      city: 'Tashkent',
      country: 'UZ',
      address: '12 Amir Timur Ave',
      checkIn: DateTime(2026, 11, 15),
      checkOut: DateTime(2026, 11, 21),
      confirmationNumber: 'NH9981',
      cost: 620,
      currency: 'USD',
    );

class _StubFx extends CurrencyService {
  @override
  Future<double> convert(double amount, String from, String to) async {
    if (from == to) return amount;
    const toUsd = {'AED': 1 / 3.67, 'USD': 1.0};
    const fromUsd = {'AED': 3.67, 'USD': 1.0};
    return amount * (toUsd[from] ?? 1.0) * (fromUsd[to] ?? 1.0);
  }

  @override
  Future<double> getRate(String from, String to) => convert(1, from, to);
}

Future<BudgetBreakdown> budgetFor(Trip trip, List<Expense> expenses) =>
    const BudgetService().build(trip, expenses, currency: _StubFx());

Expense expense(int id, double amount, String category, DateTime date) => Expense(
      id: id,
      tripId: 1,
      title: 'Expense $id',
      category: category,
      amount: amount,
      currency: 'USD',
      baseAmount: amount,
      date: date,
    );

/// A PDF is valid if it starts with the %PDF- header and ends with %%EOF.
/// Checking the trailer catches truncated writes, which is the realistic bug.
void expectValidPdf(List<int> bytes) {
  expect(bytes.length, greaterThan(500), reason: 'PDF is suspiciously small');
  final text = latin1.decode(bytes.take(16).toList(), allowInvalid: true);
  expect(text, startsWith('%PDF-'));

  final tail = latin1.decode(bytes.skip(bytes.length - 32).toList(), allowInvalid: true);
  expect(tail, contains('%%EOF'), reason: 'PDF is truncated - no %%EOF trailer');
}

void main() {
  final trip = buildTrip();

  test('produces a valid PDF from a bare trip', () async {
    final bytes = await TripPdfBuilder(trip: trip).build();
    expectValidPdf(bytes);
  });

  test('produces a valid PDF with every section populated', () async {
    final expenses = [
      expense(1, 100, 'transportation', DateTime(2026, 11, 16)),
      expense(2, 250, 'food', DateTime(2026, 11, 17)),
    ];
    final budget = await budgetFor(trip, expenses);

    final bytes = await TripPdfBuilder(trip: trip).build(
      flights: [buildFlight()],
      hotels: [buildHotel()],
      itinerary: [
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: DateTime(2026, 11, 15),
          theme: 'Arrive and check in',
          notes: 'Taxi from the airport',
        ),
      ],
      expenses: expenses,
      packing: [
        PackingItem(id: 1, tripId: 1, category: 'documents', name: 'Passport', quantity: 1, packed: true),
        PackingItem(id: 2, tripId: 1, category: 'electronics', name: 'Charger', quantity: 1, packed: false),
      ],
      budget: budget,
      allocations: {'transportation': 3000, 'food': 2000},
    );

    expectValidPdf(bytes);
    // A populated brief should be substantially bigger than a bare one.
    final bare = await TripPdfBuilder(trip: trip).build();
    expect(bytes.length, greaterThan(bare.length));
  });

  test('a PDF with no budget set still generates', () async {
    final bytes = await TripPdfBuilder(trip: buildTrip(budget: 0)).build(
      flights: [buildFlight()],
    );
    expectValidPdf(bytes);
  });

  test('a huge expense list does not hang or produce a broken file', () async {
    final many = List.generate(
      400,
      (i) => expense(i, 10, 'food', DateTime(2026, 11, 15).add(Duration(days: i % 20))),
    );
    final budget = await budgetFor(trip, many);
    final bytes = await TripPdfBuilder(trip: trip).build(expenses: many, budget: budget);
    expectValidPdf(bytes);
  });

  test('a trip with no name or currency still generates', () async {
    final blank = Trip(
      id: null,
      name: '',
      originName: '',
      originCountry: '',
      destName: '',
      destCountry: '',
      departure: DateTime(2026, 1, 1),
      returnDate: DateTime(2026, 1, 1),
      travelers: 0,
      baseCurrency: '',
      transport: '',
      totalBudget: 0,
    );
    final bytes = await TripPdfBuilder(trip: blank).build();
    expectValidPdf(bytes);
  });

  test('the PDF embeds its text, so friends can search it', () async {
    final bytes = await TripPdfBuilder(trip: trip).build(
      flights: [buildFlight()],
      hotels: [buildHotel()],
    );

    // Content streams are Flate-compressed, so grepping the raw bytes finds
    // nothing. Decompress them before asserting - otherwise this test would
    // pass no matter what the PDF actually contained.
    final raw = latin1.decode(bytes, allowInvalid: true);
    final text = StringBuffer();
    final codec = io.ZLibCodec();

    for (final match in RegExp(r'stream\r?\n([\s\S]*?)\r?\nendstream').allMatches(raw)) {
      final chunk = latin1.encode(match.group(1)!);
      try {
        text.write(utf8.decode(codec.decode(chunk), allowMalformed: true));
      } catch (_) {
        // Not a flate stream (e.g. an embedded image) - skip it.
      }
    }
    final body = text.toString();

    expect(body, isNotEmpty, reason: 'no decompressible content stream found');

    // The library emits one show-text operator per word, so multi-word
    // phrases are not contiguous. Assert on the tokens that matter.
    expect(body, contains('QK7X2M'), reason: 'flight booking reference missing from the brief');
    expect(body, contains('NH9981'), reason: 'hotel confirmation missing');
    expect(body, contains('FLYDUBAI'));
    expect(body, contains('FZ1234'));
    expect(body, contains('Novotel'));
    expect(body, contains('Tashkent'));
    expect(body, contains('Uzbek'));
    expect(body, contains('travellers'));
    expect(body, contains('9,000.00'), reason: 'trip budget missing from the brief');
  });

  test('writes a readable file to disk', () async {
    final bytes = await TripPdfBuilder(trip: trip).build(flights: [buildFlight()]);
    final dir = await io.Directory.systemTemp.createTemp('foxory-pdf');
    final file = io.File('${dir.path}/brief.pdf');
    await file.writeAsBytes(bytes);

    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(500));
    final head = (await file.openRead(0, 5).fold<List<int>>(<int>[], (a, b) => a..addAll(b)));
    expect(ascii.decode(head), '%PDF-');
    await dir.delete(recursive: true);
  });
}