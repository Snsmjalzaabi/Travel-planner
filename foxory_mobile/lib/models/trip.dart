import 'package:sqflite/sqflite.dart';
import 'hotel.dart';
import 'flight.dart';
import 'itinerary.dart';
import 'packing.dart';
import 'package:flutter/material.dart';

class Trip {
  final int? id;
  final String name;
  final String originName;
  final double? originLat;
  final double? originLon;
  final String originCountry;
  final String destName;
  final double? destLat;
  final double? destLon;
  final String destCountry;
  final DateTime departure;
  final DateTime returnDate;
  final int travelers;
  final String baseCurrency;
  final double? baseRate;
  final String transportType;
  final String status; // IDEA, PLANNING, READY, ACTIVE, COMPLETED
  final int readiness;
  final double? distance;
  final String? distanceType;
  final String? travelTime;
  final String? travelTimeSource;
  final double totalBudget;
  final double? distanceKm;
  final List<String> attractions;
  final List<String> notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncEnabled;
  final int syncStatus; // 0=none, 1=pending, 2=synced

  Trip({
    this.id,
    required this.name,
    required this.originName,
    this.originLat,
    this.originLon,
    required this.originCountry,
    required this.destName,
    this.destLat,
    this.destLon,
    required this.destCountry,
    required this.departure,
    required this.returnDate,
    this.travelers = 1,
    this.baseCurrency = 'USD',
    this.baseRate,
    this.transportType = 'flight',
    this.status = 'IDEA',
    this.readiness = 0,
    this.distance,
    this.distanceType,
    this.travelTime,
    this.travelTimeSource,
    this.totalBudget = 0,
    this.distanceKm,
    List<String>? attractions,
    List<String>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncEnabled = true,
    this.syncStatus = 0,
  })  : attractions = attractions ?? [],
        notes = notes ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'origin_name': originName,
        'origin_lat': originLat,
        'origin_lon': originLon,
        'origin_country': originCountry,
        'dest_name': destName,
        'dest_lat': destLat,
        'dest_lon': destLon,
        'dest_country': destCountry,
        'departure': departure.toIso8601String(),
        'return_date': returnDate.toIso8601String(),
        'travelers': travelers,
        'base_currency': baseCurrency,
        'base_rate': baseRate,
        'transport_type': transportType,
        'status': status,
        'readiness': readiness,
        'distance': distance,
        'distance_type': distanceType,
        'travel_time': travelTime,
        'travel_time_source': travelTimeSource,
        'total_budget': totalBudget,
        'distance_km': distanceKm,
        'attractions': attractions.join(','),
        'notes': notes.join(','),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_enabled': syncEnabled ? 1 : 0,
        'sync_status': syncStatus,
      };

  factory Trip.fromMap(Map<String, dynamic> map) => Trip(
        id: map['id'] as int?,
        name: map['name'] as String,
        originName: map['origin_name'] as String,
        originLat: map['origin_lat'] as double?,
        originLon: map['origin_lon'] as double?,
        originCountry: map['origin_country'] as String,
        destName: map['dest_name'] as String,
        destLat: map['dest_lat'] as double?,
        destLon: map['dest_lon'] as double?,
        destCountry: map['dest_country'] as String,
        departure: DateTime.parse(map['departure'] as String),
        returnDate: DateTime.parse(map['return_date'] as String),
        travelers: map['travelers'] as int? ?? 1,
        baseCurrency: map['base_currency'] as String? ?? 'USD',
        baseRate: map['base_rate'] as double?,
        transportType: map['transport_type'] as String? ?? 'flight',
        status: map['status'] as String? ?? 'IDEA',
        readiness: map['readiness'] as int? ?? 0,
        distance: map['distance'] as double?,
        distanceType: map['distance_type'] as String?,
        travelTime: map['travel_time'] as String?,
        travelTimeSource: map['travel_time_source'] as String?,
        totalBudget: map['total_budget'] as double? ?? 0,
        distanceKm: map['distance_km'] as double?,
        attractions: (map['attractions'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        notes: (map['notes'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "trips" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "name" TEXT NOT NULL,
      "origin_name" TEXT NOT NULL,
      "origin_lat" REAL,
      "origin_lon" REAL,
      "origin_country" TEXT NOT NULL,
      "dest_name" TEXT NOT NULL,
      "dest_lat" REAL,
      "dest_lon" REAL,
      "dest_country" TEXT NOT NULL,
      "departure" TEXT NOT NULL,
      "return_date" TEXT NOT NULL,
      "travelers" INTEGER DEFAULT 1,
      "base_currency" TEXT DEFAULT 'USD',
      "base_rate" REAL,
      "transport_type" TEXT DEFAULT 'flight',
      "status" TEXT DEFAULT 'IDEA',
      "readiness" INTEGER DEFAULT 0,
      "distance" REAL,
      "distance_type" TEXT,
      "travel_time" TEXT,
      "travel_time_source" TEXT,
      "total_budget" REAL DEFAULT 0,
      "distance_km" REAL,
      "attractions" TEXT DEFAULT '',
      "notes" TEXT DEFAULT '',
      "created_at" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL,
      "sync_enabled" INTEGER DEFAULT 1,
      "sync_status" INTEGER DEFAULT 0
    )
  ''';

  int get nights => returnDate.difference(departure).inDays;

  String get transportLabel => {
        'flight': 'Flight',
        'car': 'Road Trip',
        'train': 'Train',
        'bus': 'Bus',
        'boat': 'Cruise/Ferry',
        'mixed': 'Mixed',
      }[transportType] ?? transportType;

  List<Hotel>? get tripHotels => hotels;
  List<Flight>? get tripFlights => flights;
  List<ItineraryDay>? get itineraryDays => null;
  List<PackingItem>? get packingItems => null;
  List<Hotel>? get hotels => null;
  List<Flight>? get flights => null;

  Trip copyWith({
    int? id,
    String? name,
    double? originLat,
    double? originLon,
    String? originCountry,
    String? destName,
    double? destLat,
    double? destLon,
    String? destCountry,
    DateTime? departure,
    DateTime? returnDate,
    int? travelers,
    String? baseCurrency,
    double? baseRate,
    String? transportType,
    String? status,
    int? readiness,
    double? distance,
    String? distanceType,
    String? travelTime,
    String? travelTimeSource,
    double? totalBudget,
    double? distanceKm,
    List<String>? attractions,
    List<String>? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncEnabled,
    int? syncStatus,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      originName: originName,
      originLat: originLat ?? this.originLat,
      originLon: originLon ?? this.originLon,
      originCountry: originCountry ?? this.originCountry,
      destName: destName ?? this.destName,
      destLat: destLat ?? this.destLat,
      destLon: destLon ?? this.destLon,
      destCountry: destCountry ?? this.destCountry,
      departure: departure ?? this.departure,
      returnDate: returnDate ?? this.returnDate,
      travelers: travelers ?? this.travelers,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      baseRate: baseRate ?? this.baseRate,
      transportType: transportType ?? this.transportType,
      status: status ?? this.status,
      readiness: readiness ?? this.readiness,
      distance: distance ?? this.distance,
      distanceType: distanceType ?? this.distanceType,
      travelTime: travelTime ?? this.travelTime,
      travelTimeSource: travelTimeSource ?? this.travelTimeSource,
      totalBudget: totalBudget ?? this.totalBudget,
      distanceKm: distanceKm ?? this.distanceKm,
      attractions: attractions ?? this.attractions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
