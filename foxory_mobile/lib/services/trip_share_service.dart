import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/database_helper.dart';
import '../models/models.dart';
import 'budget_service.dart';
import 'currency_service.dart';
import 'trip_pdf_service.dart';

/// Builds the shareable trip PDF and hands it to the phone's share sheet.
///
/// The app is single-user: Sultan plans, then sends this PDF to friends. So
/// generation happens on-device and goes straight to whatever he wants to
/// share with - WhatsApp, email, Drive - rather than needing an account here.
class TripShareService {
  const TripShareService();

  Future<Uint8List> buildPdf(Trip trip, {bool includeExpenses = true, bool includeBudget = true}) async {
    final helper = DatabaseHelper();
    final db = await helper.database;

    Future<List<Map<String, Object?>>> rowsOf(String table, int id) {
      return db.query(table, where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id]);
    }

    final id = trip.id;
    if (id == null) {
      return TripPdfBuilder(trip: trip).build();
    }

    final flights = (await rowsOf('flights', id)).map(Flight.fromMap).toList();
    final hotels = (await rowsOf('hotels', id)).map(Hotel.fromMap).toList();
    final itinerary = (await rowsOf('itinerary_days', id)).map(ItineraryDay.fromMap).toList();
    final packing = (await rowsOf('packing_items', id)).map(PackingItem.fromMap).toList();
    final expenseRows = (await rowsOf('expenses', id)).map(Expense.fromMap).toList();
    final allocations = await helper.getBudgetAllocations(id);

    BudgetBreakdown? budget;
    if (includeBudget || includeExpenses) {
      try {
        budget = await const BudgetService().build(
          trip,
          expenseRows,
          currency: CurrencyService(),
        );
      } catch (_) {
        // Offline, or the rate API is unreachable - the rest of the brief is
        // still worth producing without the budget section.
        budget = null;
      }
    }

    return TripPdfBuilder(trip: trip).build(
      flights: flights,
      hotels: hotels,
      itinerary: itinerary,
      expenses: includeExpenses ? expenseRows : const [],
      packing: packing,
      budget: includeBudget ? budget : null,
      allocations: allocations,
      includeBudget: includeBudget,
      includeExpenses: includeExpenses,
    );
  }

  /// Writes to a temp file and opens the system share sheet.
  Future<void> share(Trip trip, {bool includeExpenses = true, bool includeBudget = true}) async {
    final bytes = await buildPdf(trip, includeExpenses: includeExpenses, includeBudget: includeBudget);

    final safeName = trip.name.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final name = '${safeName.isEmpty ? 'Trip' : safeName} brief.pdf';

    if (kIsWeb) {
      // No filesystem on web - hand the bytes to the browser instead.
      // Blob download is handled by the caller on web builds.
      await SharePlus.instance.share(
        ShareParams(files: [XFile.fromData(bytes, mimeType: 'application/pdf', name: name)]),
      );
      return;
    }

    final dir = Directory('${Directory.systemTemp.path}/foxory-shares');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf', name: name)],
        subject: '${trip.name} trip brief',
      ),
    );
  }
}