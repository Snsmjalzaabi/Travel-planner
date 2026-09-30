
class ItineraryDay {
  final int? id;
  final int tripId;
  final int dayNumber;
  final DateTime date;
  final String? theme;
  final String notes;
  final int orderIndex;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncEnabled;
  final int syncStatus;

  ItineraryDay({
    this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    this.theme,
    this.notes = '',
    this.orderIndex = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncEnabled = true,
    this.syncStatus = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'day_number': dayNumber,
        'date': date.toIso8601String(),
        'theme': theme,
        'notes': notes,
        'order_index': orderIndex,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_enabled': syncEnabled ? 1 : 0,
        'sync_status': syncStatus,
      };

  factory ItineraryDay.fromMap(Map<String, dynamic> map) => ItineraryDay(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int,
        dayNumber: map['day_number'] as int,
        date: DateTime.parse(map['date'] as String),
        theme: map['theme'] as String?,
        notes: map['notes'] as String? ?? '',
        orderIndex: map['order_index'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "itinerary_days" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "trip_id" INTEGER NOT NULL,
      "day_number" INTEGER NOT NULL,
      "date" TEXT NOT NULL,
      "theme" TEXT,
      "notes" TEXT DEFAULT '',
      "order_index" INTEGER DEFAULT 0,
      "created_at" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL,
      "sync_enabled" INTEGER DEFAULT 1,
      "sync_status" INTEGER DEFAULT 0
    )
  ''';

  ItineraryDay copyWith({
    int? id,
    int? tripId,
    int? dayNumber,
    DateTime? date,
    String? theme,
    String? notes,
    int? orderIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncEnabled,
    int? syncStatus,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      theme: theme ?? this.theme,
      notes: notes ?? this.notes,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ItineraryActivity {
  final int? id;
  final int tripId;
  final int? dayId;
  final int dayNumber;
  final int orderIndex;
  final String title;
  final String? description;
  final DateTime? startTime;
  final DateTime? endTime;
  final String category; // activity, meal, transport, free_time, event, shopping
  final String? location;
  final double? lat;
  final double? lon;
  final String? address;
  final double? cost;
  final String currency;
  final int? durationMinutes;
  String? durationDisplay;
  final String? bookingRef;
  final String? notes;
  final bool done;
  final bool important;
  final int reminderMinutes; // 0 = no reminder
  final String? photoId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool syncEnabled;
  final int syncStatus;

  ItineraryActivity({
    this.id,
    required this.tripId,
    this.dayId,
    required this.dayNumber,
    this.orderIndex = 0,
    required this.title,
    this.description,
    this.startTime,
    this.endTime,
    this.category = 'activity',
    this.location,
    this.lat,
    this.lon,
    this.address,
    this.cost,
    this.currency = 'USD',
    this.durationMinutes,
    this.bookingRef,
    this.notes,
    this.done = false,
    this.important = false,
    this.reminderMinutes = 0,
    this.photoId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncEnabled = true,
    this.syncStatus = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        durationDisplay = _durationToDisplay(durationMinutes);

  static String _durationToDisplay(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'day_id': dayId,
        'day_number': dayNumber,
        'order_index': orderIndex,
        'title': title,
        'description': description,
        'start_time': startTime?.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'category': category,
        'location': location,
        'lat': lat,
        'lon': lon,
        'address': address,
        'cost': cost,
        'currency': currency,
        'duration_minutes': durationMinutes,
        'duration_display': durationDisplay,
        'booking_ref': bookingRef,
        'notes': notes,
        'done': done ? 1 : 0,
        'important': important ? 1 : 0,
        'reminder_minutes': reminderMinutes,
        'photo_id': photoId,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_enabled': syncEnabled ? 1 : 0,
        'sync_status': syncStatus,
      };

  factory ItineraryActivity.fromMap(Map<String, dynamic> map) => ItineraryActivity(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int,
        dayId: map['day_id'] as int?,
        dayNumber: map['day_number'] as int,
        orderIndex: map['order_index'] as int? ?? 0,
        title: map['title'] as String,
        description: map['description'] as String?,
        startTime: map['start_time'] != null
            ? DateTime.parse(map['start_time'] as String)
            : null,
        endTime: map['end_time'] != null
            ? DateTime.parse(map['end_time'] as String)
            : null,
        category: map['category'] as String? ?? 'activity',
        location: map['location'] as String?,
        lat: map['lat'] as double?,
        lon: map['lon'] as double?,
        address: map['address'] as String?,
        cost: map['cost'] as double?,
        currency: map['currency'] as String? ?? 'USD',
        durationMinutes: map['duration_minutes'] as int?,
        bookingRef: map['booking_ref'] as String?,
        notes: map['notes'] as String?,
        done: (map['done'] as int? ?? 0) == 1,
        important: (map['important'] as int? ?? 0) == 1,
        reminderMinutes: map['reminder_minutes'] as int? ?? 0,
        photoId: map['photo_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "itinerary_activities" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "trip_id" INTEGER NOT NULL,
      "day_id" INTEGER,
      "day_number" INTEGER NOT NULL,
      "order_index" INTEGER DEFAULT 0,
      "title" TEXT NOT NULL,
      "description" TEXT,
      "start_time" TEXT,
      "end_time" TEXT,
      "category" TEXT DEFAULT 'activity',
      "location" TEXT,
      "lat" REAL,
      "lon" REAL,
      "address" TEXT,
      "cost" REAL,
      "currency" TEXT DEFAULT 'USD',
      "duration_minutes" INTEGER,
      "duration_display" TEXT,
      "booking_ref" TEXT,
      "notes" TEXT,
      "done" INTEGER DEFAULT 0,
      "important" INTEGER DEFAULT 0,
      "reminder_minutes" INTEGER DEFAULT 0,
      "photo_id" TEXT,
      "created_at" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL,
      "sync_enabled" INTEGER DEFAULT 1,
      "sync_status" INTEGER DEFAULT 0
    )
  ''';

  ItineraryActivity copyWith({
    int? id,
    int? tripId,
    int? dayId,
    int? dayNumber,
    int? orderIndex,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? category,
    String? location,
    double? lat,
    double? lon,
    String? address,
    double? cost,
    String? currency,
    int? durationMinutes,
    String? durationDisplay,
    String? bookingRef,
    String? notes,
    bool? done,
    bool? important,
    int? reminderMinutes,
    String? photoId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? syncEnabled,
    int? syncStatus,
  }) {
    return ItineraryActivity(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayId: dayId ?? this.dayId,
      dayNumber: dayNumber ?? this.dayNumber,
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      category: category ?? this.category,
      location: location ?? this.location,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      address: address ?? this.address,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      
      bookingRef: bookingRef ?? this.bookingRef,
      notes: notes ?? this.notes,
      done: done ?? this.done,
      important: important ?? this.important,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      photoId: photoId ?? this.photoId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
