import 'package:sqflite/sqflite.dart';

class Hotel {
  final int? id;
  final int tripId;
  final String name;
  final String address;
  final double? lat;
  final double? lon;
  final String city;
  final String country;
  final DateTime checkIn;
  final DateTime checkOut;
  final double? cost;
  final String currency;
  final String? confirmationNumber;
  final String? phone;
  final String? website;
  final String? bookingUrl;
  final String notes;
  final bool bookmarked;
  final int rating; // 1-5
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncEnabled;
  final int syncStatus;

  Hotel({
    this.id,
    required this.tripId,
    required this.name,
    required this.address,
    this.lat,
    this.lon,
    required this.city,
    required this.country,
    required this.checkIn,
    required this.checkOut,
    this.cost,
    this.currency = 'USD',
    this.confirmationNumber,
    this.phone,
    this.website,
    this.bookingUrl,
    this.notes = '',
    this.bookmarked = false,
    this.rating = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncEnabled = true,
    this.syncStatus = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'name': name,
        'address': address,
        'lat': lat,
        'lon': lon,
        'city': city,
        'country': country,
        'check_in': checkIn.toIso8601String(),
        'check_out': checkOut.toIso8601String(),
        'cost': cost,
        'currency': currency,
        'confirmation_number': confirmationNumber,
        'phone': phone,
        'website': website,
        'booking_url': bookingUrl,
        'notes': notes,
        'bookmarked': bookmarked ? 1 : 0,
        'rating': rating,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_enabled': syncEnabled ? 1 : 0,
        'sync_status': syncStatus,
      };

  factory Hotel.fromMap(Map<String, dynamic> map) => Hotel(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int,
        name: map['name'] as String,
        address: map['address'] as String,
        lat: map['lat'] as double?,
        lon: map['lon'] as double?,
        city: map['city'] as String,
        country: map['country'] as String,
        checkIn: DateTime.parse(map['check_in'] as String),
        checkOut: DateTime.parse(map['check_out'] as String),
        cost: map['cost'] as double?,
        currency: map['currency'] as String? ?? 'USD',
        confirmationNumber: map['confirmation_number'] as String?,
        phone: map['phone'] as String?,
        website: map['website'] as String?,
        bookingUrl: map['booking_url'] as String?,
        notes: map['notes'] as String? ?? '',
        bookmarked: (map['bookmarked'] as int? ?? 0) == 1,
        rating: map['rating'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "hotels" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "trip_id" INTEGER NOT NULL,
      "name" TEXT NOT NULL,
      "address" TEXT NOT NULL,
      "lat" REAL,
      "lon" REAL,
      "city" TEXT NOT NULL,
      "country" TEXT NOT NULL,
      "check_in" TEXT NOT NULL,
      "check_out" TEXT NOT NULL,
      "cost" REAL,
      "currency" TEXT DEFAULT 'USD',
      "confirmation_number" TEXT,
      "phone" TEXT,
      "website" TEXT,
      "booking_url" TEXT,
      "notes" TEXT DEFAULT '',
      "bookmarked" INTEGER DEFAULT 0,
      "rating" INTEGER DEFAULT 0,
      "created_at" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL,
      "sync_enabled" INTEGER DEFAULT 1,
      "sync_status" INTEGER DEFAULT 0
    )
  ''';

  Hotel copyWith({
    int? id,
    int? tripId,
    String? name,
    String? address,
    double? lat,
    double? lon,
    String? city,
    String? country,
    DateTime? checkIn,
    DateTime? checkOut,
    double? cost,
    String? currency,
    String? confirmationNumber,
    String? phone,
    String? website,
    String? bookingUrl,
    String? notes,
    bool? bookmarked,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncEnabled,
    int? syncStatus,
  }) {
    return Hotel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      city: city ?? this.city,
      country: country ?? this.country,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      confirmationNumber: confirmationNumber ?? this.confirmationNumber,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      notes: notes ?? this.notes,
      bookmarked: bookmarked ?? this.bookmarked,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
