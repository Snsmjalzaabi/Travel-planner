import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/database_helper.dart';
import '../models/models.dart';

class ExportImportService {
  final DatabaseHelper _dbHelper;

  ExportImportService(this._dbHelper);

  Future<String> exportTripAsJson(Trip trip) async {
    final tripData = _exportTripWithRelations(trip);
    final jsonString = const JsonEncoder.withIndent('  ').convert(tripData);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'foxory_trip_${trip.name.replaceAll(' ', '_')}_$timestamp.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonString);

    return file.path;
  }

  TripData _exportTripWithRelations(Trip trip) {
    return TripData(
      trip: trip,
      hotels: [],
      flights: [],
      itineraryDays: [],
      itineraryActivities: [],
      expenses: [],
      packingItems: [],
      photos: [],
      notes: [],
      exportedAt: DateTime.now(),
    );
  }

  Future<String> exportAllTripsAsJson() async {
    final db = await _dbHelper.database;
    final trips = await db.query('trips', orderBy: 'created_at DESC');
    final tripList = trips.map((m) => Trip.fromMap(m)).toList();

    final allData = <TripData>[];
    for (final trip in tripList) {
      allData.add(TripData(
        trip: trip,
        hotels: [],
        flights: [],
        itineraryDays: [],
        itineraryActivities: [],
        expenses: [],
        packingItems: [],
        photos: [],
        notes: [],
        exportedAt: DateTime.now(),
      ));
    }

    final data = AllTripsData(
      exportedAt: DateTime.now(),
      deviceId: 'phone',
      trips: allData,
    );

    final jsonString = const JsonEncoder.withIndent('  ').convert(data.toJson());

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'foxory_all_trips_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(jsonString);

    return file.path;
  }

  Future<void> importTripFromJson(String jsonPath) async {
    final file = File(jsonPath);
    if (!await file.exists()) {
      throw Exception('File not found: $jsonPath');
    }

    final jsonString = await file.readAsString();
    final data = TripData.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);

    // Import the trip
    final tripMap = data.trip.toMap();
    tripMap['id'] = null; // Let DB auto-assign
    tripMap['created_at'] = DateTime.now().toIso8601String();
    tripMap['updated_at'] = DateTime.now().toIso8601String();
    await _dbHelper.insert('trips', tripMap);
    final newTripId = await _dbHelper.rawQuery(
      'SELECT last_insert_rowid() as id',
    );
    final tripId = newTripId.first['id'] as int;

    // Import related data
    for (final hotel in data.hotels) {
      final hm = hotel.toMap();
      hm['id'] = null;
      hm['trip_id'] = tripId;
      hm['created_at'] = DateTime.now().toIso8601String();
      hm['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('hotels', hm);
    }

    for (final flight in data.flights) {
      final fm = flight.toMap();
      fm['id'] = null;
      fm['trip_id'] = tripId;
      fm['created_at'] = DateTime.now().toIso8601String();
      fm['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('flights', fm);
    }

    for (final day in data.itineraryDays) {
      final dm = day.toMap();
      dm['id'] = null;
      dm['trip_id'] = tripId;
      dm['created_at'] = DateTime.now().toIso8601String();
      dm['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('itinerary_days', dm);
    }

    for (final activity in data.itineraryActivities) {
      final am = activity.toMap();
      am['id'] = null;
      am['trip_id'] = tripId;
      am['day_id'] = null;
      am['created_at'] = DateTime.now().toIso8601String();
      am['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('itinerary_activities', am);
    }

    for (final expense in data.expenses) {
      final em = expense.toMap();
      em['id'] = null;
      em['trip_id'] = tripId;
      em['created_at'] = DateTime.now().toIso8601String();
      em['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('expenses', em);
    }

    for (final item in data.packingItems) {
      final im = item.toMap();
      im['id'] = null;
      im['trip_id'] = tripId;
      im['created_at'] = DateTime.now().toIso8601String();
      im['updated_at'] = DateTime.now().toIso8601String();
      await _dbHelper.insert('packing_items', im);
    }
  }

  Future<String> shareTripJson(Trip trip) async {
    return exportTripAsJson(trip);
  }

  Future<String> shareAllTripsJson() async {
    return exportAllTripsAsJson();
  }
}

// Data transfer objects for export
class TripData {
  final Trip trip;
  final List<Hotel> hotels;
  final List<Flight> flights;
  final List<ItineraryDay> itineraryDays;
  final List<ItineraryActivity> itineraryActivities;
  final List<Expense> expenses;
  final List<PackingItem> packingItems;
  final List<Photo> photos;
  final List<Note> notes;
  final DateTime exportedAt;

  TripData({
    required this.trip,
    required this.hotels,
    required this.flights,
    required this.itineraryDays,
    required this.itineraryActivities,
    required this.expenses,
    required this.packingItems,
    required this.photos,
    required this.notes,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
        'trip': trip.toMap(),
        'hotels': hotels.map((h) => h.toMap()).toList(),
        'flights': flights.map((f) => f.toMap()).toList(),
        'itinerary_days': itineraryDays.map((d) => d.toMap()).toList(),
        'itinerary_activities': itineraryActivities.map((a) => a.toMap()).toList(),
        'expenses': expenses.map((e) => e.toMap()).toList(),
        'packing_items': packingItems.map((p) => p.toMap()).toList(),
        'photos': photos.map((p) => p.toMap()).toList(),
        'notes': notes.map((n) => n.toMap()).toList(),
        'exported_at': exportedAt.toIso8601String(),
      };

  factory TripData.fromJson(Map<String, dynamic> json) => TripData(
        trip: Trip.fromMap(json['trip'] as Map<String, dynamic>),
        hotels: (json['hotels'] as List<dynamic>?)
                ?.map((h) => Hotel.fromMap(h as Map<String, dynamic>))
                .toList() ??
            [],
        flights: (json['flights'] as List<dynamic>?)
                ?.map((f) => Flight.fromMap(f as Map<String, dynamic>))
                .toList() ??
            [],
        itineraryDays: (json['itinerary_days'] as List<dynamic>?)
                ?.map((d) => ItineraryDay.fromMap(d as Map<String, dynamic>))
                .toList() ??
            [],
        itineraryActivities: (json['itinerary_activities'] as List<dynamic>?)
                ?.map((a) => ItineraryActivity.fromMap(a as Map<String, dynamic>))
                .toList() ??
            [],
        expenses: (json['expenses'] as List<dynamic>?)
                ?.map((e) => Expense.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        packingItems: (json['packing_items'] as List<dynamic>?)
                ?.map((p) => PackingItem.fromMap(p as Map<String, dynamic>))
                .toList() ??
            [],
        photos: (json['photos'] as List<dynamic>?)
                ?.map((p) => Photo.fromMap(p as Map<String, dynamic>))
                .toList() ??
            [],
        notes: (json['notes'] as List<dynamic>?)
                ?.map((n) => Note.fromMap(n as Map<String, dynamic>))
                .toList() ??
            [],
        exportedAt: DateTime.parse(json['exported_at'] as String),
      );
}

class AllTripsData {
  final DateTime exportedAt;
  final String deviceId;
  final List<TripData> trips;

  AllTripsData({
    required this.exportedAt,
    required this.deviceId,
    required this.trips,
  });

  Map<String, dynamic> toJson() => {
        'exported_at': exportedAt.toIso8601String(),
        'device_id': deviceId,
        'trips': trips.map((t) => t.toJson()).toList(),
      };

  factory AllTripsData.fromJson(Map<String, dynamic> json) => AllTripsData(
        exportedAt: DateTime.parse(json['exported_at'] as String),
        deviceId: json['device_id'] as String,
        trips: (json['trips'] as List<dynamic>)
            .map((t) => TripData.fromJson(t as Map<String, dynamic>))
            .toList(),
      );
}
