import 'package:sqflite/sqflite.dart';

class Flight {
  final int? id;
  final int tripId;
  final String airline;
  final String flightNumber;
  final String fromCity;
  final String fromCountry;
  final double? fromLat;
  final double? fromLon;
  final String fromCode;
  final String toCity;
  final String toCountry;
  final double? toLat;
  final double? toLon;
  final String toCode;
  final DateTime departure;
  final DateTime arrival;
  final String departureTerminal;
  final String arrivalTerminal;
  final String departureGate;
  final String arrivalGate;
  final double? cost;
  final String currency;
  final String seat;
  final String status; // CONFIRMED, BOARDING, DEPARTED, ARRIVED, CANCELLED, DELAYED
  final String? bookingReference;
  final String? confirmationNumber;
  final String notes;
  final bool bookmarked;
  final int durationMinutes;
  String? durationDisplay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncEnabled;
  final int syncStatus;

  Flight({
    this.id,
    required this.tripId,
    required this.airline,
    required this.flightNumber,
    required this.fromCity,
    required this.fromCountry,
    this.fromLat,
    this.fromLon,
    this.fromCode = '',
    required this.toCity,
    required this.toCountry,
    this.toLat,
    this.toLon,
    this.toCode = '',
    required this.departure,
    required this.arrival,
    this.departureTerminal = '',
    this.arrivalTerminal = '',
    this.departureGate = '',
    this.arrivalGate = '',
    this.cost,
    this.currency = 'USD',
    this.seat = '',
    this.status = 'CONFIRMED',
    this.bookingReference,
    this.confirmationNumber,
    this.notes = '',
    this.bookmarked = false,
    this.durationMinutes = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncEnabled = true,
    this.syncStatus = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        durationDisplay = _formatDuration(durationMinutes);

  static String _formatDuration(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h h';
    return '${h}h ${m}m';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'airline': airline,
        'flight_number': flightNumber,
        'from_city': fromCity,
        'from_country': fromCountry,
        'from_lat': fromLat,
        'from_lon': fromLon,
        'from_code': fromCode,
        'to_city': toCity,
        'to_country': toCountry,
        'to_lat': toLat,
        'to_lon': toLon,
        'to_code': toCode,
        'departure': departure.toIso8601String(),
        'arrival': arrival.toIso8601String(),
        'departure_terminal': departureTerminal,
        'arrival_terminal': arrivalTerminal,
        'departure_gate': departureGate,
        'arrival_gate': arrivalGate,
        'cost': cost,
        'currency': currency,
        'seat': seat,
        'status': status,
        'booking_reference': bookingReference,
        'confirmation_number': confirmationNumber,
        'notes': notes,
        'bookmarked': bookmarked ? 1 : 0,
        'duration_minutes': durationMinutes,
        'duration_display': durationDisplay,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_enabled': syncEnabled ? 1 : 0,
        'sync_status': syncStatus,
      };

  factory Flight.fromMap(Map<String, dynamic> map) => Flight(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int,
        airline: map['airline'] as String,
        flightNumber: map['flight_number'] as String,
        fromCity: map['from_city'] as String,
        fromCountry: map['from_country'] as String,
        fromLat: map['from_lat'] as double?,
        fromLon: map['from_lon'] as double?,
        fromCode: map['from_code'] as String? ?? '',
        toCity: map['to_city'] as String,
        toCountry: map['to_country'] as String,
        toLat: map['to_lat'] as double?,
        toLon: map['to_lon'] as double?,
        toCode: map['to_code'] as String? ?? '',
        departure: DateTime.parse(map['departure'] as String),
        arrival: DateTime.parse(map['arrival'] as String),
        departureTerminal: map['departure_terminal'] as String? ?? '',
        arrivalTerminal: map['arrival_terminal'] as String? ?? '',
        departureGate: map['departure_gate'] as String? ?? '',
        arrivalGate: map['arrival_gate'] as String? ?? '',
        cost: map['cost'] as double?,
        currency: map['currency'] as String? ?? 'USD',
        seat: map['seat'] as String? ?? '',
        status: map['status'] as String? ?? 'CONFIRMED',
        bookingReference: map['booking_reference'] as String?,
        confirmationNumber: map['confirmation_number'] as String?,
        notes: map['notes'] as String? ?? '',
        bookmarked: (map['bookmarked'] as int? ?? 0) == 1,
        durationMinutes: map['duration_minutes'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "flights" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "trip_id" INTEGER NOT NULL,
      "airline" TEXT NOT NULL,
      "flight_number" TEXT NOT NULL,
      "from_city" TEXT NOT NULL,
      "from_country" TEXT NOT NULL,
      "from_lat" REAL,
      "from_lon" REAL,
      "from_code" TEXT,
      "to_city" TEXT NOT NULL,
      "to_country" TEXT NOT NULL,
      "to_lat" REAL,
      "to_lon" REAL,
      "to_code" TEXT,
      "departure" TEXT NOT NULL,
      "arrival" TEXT NOT NULL,
      "departure_terminal" TEXT,
      "arrival_terminal" TEXT,
      "departure_gate" TEXT,
      "arrival_gate" TEXT,
      "cost" REAL,
      "currency" TEXT DEFAULT 'USD',
      "seat" TEXT,
      "status" TEXT DEFAULT 'CONFIRMED',
      "booking_reference" TEXT,
      "confirmation_number" TEXT,
      "notes" TEXT DEFAULT '',
      "bookmarked" INTEGER DEFAULT 0,
      "duration_minutes" INTEGER DEFAULT 0,
      "duration_display" TEXT,
      "created_at" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL,
      "sync_enabled" INTEGER DEFAULT 1,
      "sync_status" INTEGER DEFAULT 0
    )
  ''';

  Flight copyWith({
    int? id,
    int? tripId,
    String? airline,
    String? flightNumber,
    String? fromCity,
    String? fromCountry,
    double? fromLat,
    double? fromLon,
    String? fromCode,
    String? toCity,
    String? toCountry,
    double? toLat,
    double? toLon,
    String? toCode,
    DateTime? departure,
    DateTime? arrival,
    String? departureTerminal,
    String? arrivalTerminal,
    String? departureGate,
    String? arrivalGate,
    double? cost,
    String? currency,
    String? seat,
    String? status,
    String? bookingReference,
    String? confirmationNumber,
    String? notes,
    bool? bookmarked,
    int? durationMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncEnabled,
    int? syncStatus,
  }) {
    return Flight(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      airline: airline ?? this.airline,
      flightNumber: flightNumber ?? this.flightNumber,
      fromCity: fromCity ?? this.fromCity,
      fromCountry: fromCountry ?? this.fromCountry,
      fromLat: fromLat ?? this.fromLat,
      fromLon: fromLon ?? this.fromLon,
      fromCode: fromCode ?? this.fromCode,
      toCity: toCity ?? this.toCity,
      toCountry: toCountry ?? this.toCountry,
      toLat: toLat ?? this.toLat,
      toLon: toLon ?? this.toLon,
      toCode: toCode ?? this.toCode,
      departure: departure ?? this.departure,
      arrival: arrival ?? this.arrival,
      departureTerminal: departureTerminal ?? this.departureTerminal,
      arrivalTerminal: arrivalTerminal ?? this.arrivalTerminal,
      departureGate: departureGate ?? this.departureGate,
      arrivalGate: arrivalGate ?? this.arrivalGate,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      seat: seat ?? this.seat,
      status: status ?? this.status,
      bookingReference: bookingReference ?? this.bookingReference,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
      notes: notes ?? this.notes,
      bookmarked: bookmarked ?? this.bookmarked,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
