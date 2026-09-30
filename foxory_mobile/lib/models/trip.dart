import 'hotel.dart';
import 'flight.dart';
import 'itinerary.dart';
import 'packing.dart';
import 'personal_info.dart';

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
  final String transport;
  final String status;
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
  final int syncStatus;
  final String? destinationImage;
  final String transportLabel;
  final PersonalInfo? personalInfo;

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
    required this.transport,
    this.status = 'IDEA',
    this.readiness = 0,
    this.distance,
    this.distanceType,
    this.travelTime,
    this.travelTimeSource,
    this.totalBudget = 0,
    this.distanceKm,
    this.destinationImage,
    this.transportLabel = 'Flight',
    this.personalInfo,
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
        'transport': transport,
        'status': status,
        'readiness': readiness,
        'distance': distance,
        'distance_type': distanceType,
        'travel_time': travelTime,
        'travel_time_source': travelTimeSource,
        'total_budget': totalBudget,
        'distance_km': distanceKm,
        'destination_image': destinationImage,
        'transport_label': transportLabel,
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
        transport: map['transport'] as String? ?? 'flight',
        status: map['status'] as String? ?? 'IDEA',
        readiness: map['readiness'] as int? ?? 0,
        distance: map['distance'] as double?,
        distanceType: map['distance_type'] as String?,
        travelTime: map['travel_time'] as String?,
        travelTimeSource: map['travel_time_source'] as String?,
        totalBudget: map['total_budget'] as double? ?? 0,
        distanceKm: map['distance_km'] as double?,
        destinationImage:
            map['destination_image'] as String? ?? null,
        transportLabel: map['transport_label'] as String? ?? 'Flight',
        personalInfo: map['personal_info'] != null
            ? PersonalInfo.fromMap(map['personal_info'] as Map<String, dynamic>)
            : null,
        attractions: (map['attractions'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        notes: (map['notes'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  int get nights => returnDate.difference(departure).inDays;

  List<Hotel>? get hotels => null;
  List<Flight>? get flights => null;
  List<ItineraryDay>? get itineraryDays => null;
  List<PackingItem>? get packingItems => null;

  List<Hotel>? get tripHotels => hotels;
  List<Flight>? get tripFlights => flights;

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
    String? transport,
    String? status,
    int? readiness,
    double? distance,
    String? distanceType,
    String? travelTime,
    String? travelTimeSource,
    double? totalBudget,
    double? distanceKm,
    String? destinationImage,
    String? transportLabel,
    PersonalInfo? personalInfo,
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
      transport: transport ?? this.transport,
      status: status ?? this.status,
      readiness: readiness ?? this.readiness,
      distance: distance ?? this.distance,
      distanceType: distanceType ?? this.distanceType,
      travelTime: travelTime ?? this.travelTime,
      travelTimeSource: travelTimeSource ?? this.travelTimeSource,
      totalBudget: totalBudget ?? this.totalBudget,
      distanceKm: distanceKm ?? this.distanceKm,
      destinationImage: destinationImage ?? this.destinationImage,
      transportLabel: transportLabel ?? this.transportLabel,
      personalInfo: personalInfo ?? this.personalInfo,
      attractions: attractions ?? this.attractions,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
