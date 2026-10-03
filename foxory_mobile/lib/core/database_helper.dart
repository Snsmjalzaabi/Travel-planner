import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class DatabaseHelper {
  static Database? _database;

  Future<void> init() async {
    // Tables are created on first database open
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  /// Test-only override so unit tests can use a throwaway DB file.
  /// Leave null in the app; sqflite picks the platform default path.
  static String? testOverridePath;

  Future<Database> _initDB() async {
    final dbPath = testOverridePath ??
        join((await getApplicationDocumentsDirectory()).path, 'foxory.db');
    return openDatabase(
      dbPath,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async => _ensureSchema(db),
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _ensureSchema(db);
  }

  /// Tables that take part in sync. Order matters: parents before children,
  /// so foreign keys (hotels -> trips) resolve.
  static const syncTables = <String>[
    'trips',
    'hotels',
    'flights',
    'itinerary_days',
    'itinerary_activities',
    'expenses',
    'packing_items',
    'passports',
    'visas',
    'notes',
    'tasks',
    'app_files',
  ];

  Future<void> _ensureSchema(Database db) async {
    await _addColumnIfMissing(db, 'trips', 'transport_label', 'TEXT DEFAULT \'Flight\'');
    await _addColumnIfMissing(db, 'trips', 'trip_type', 'TEXT DEFAULT \'friends\'');
    await _addColumnIfMissing(db, 'trips', 'destination_image', 'TEXT');
    // Soft deletes so a restore never resurrects a row the user removed.
    for (final table in syncTables) {
      await _addColumnIfMissing(db, table, 'deleted_at', 'TEXT');
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
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
        "transport_label" TEXT DEFAULT 'Flight',
        "trip_type" TEXT DEFAULT 'friends',
        "status" TEXT DEFAULT 'IDEA',
        "readiness" INTEGER DEFAULT 0,
        "distance" REAL,
        "distance_type" TEXT,
        "travel_time" TEXT,
        "travel_time_source" TEXT,
        "total_budget" REAL DEFAULT 0,
        "distance_km" REAL,
        "destination_image" TEXT,
        "attractions" TEXT DEFAULT '',
        "notes" TEXT DEFAULT '',
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_enabled" INTEGER DEFAULT 1,
        "sync_status" INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
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
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "passports" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "passport_number" TEXT NOT NULL,
        "country" TEXT NOT NULL,
        "country_code" TEXT NOT NULL,
        "issued_date" TEXT NOT NULL,
        "expiry_date" TEXT NOT NULL,
        "issuing_authority" TEXT,
        "holder_name" TEXT,
        "nationality" TEXT,
        "place_of_birth" TEXT,
        "date_of_birth" TEXT,
        "tax_id" TEXT,
        "photo_path" TEXT,
        "notes" TEXT DEFAULT '',
        "expiry_alert_months" INTEGER DEFAULT 6,
        "expired" INTEGER DEFAULT 0,
        "expiring_soon" INTEGER DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "visas" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "passport_id" INTEGER,
        "country" TEXT NOT NULL,
        "country_code" TEXT NOT NULL,
        "visa_type" TEXT NOT NULL,
        "status" TEXT NOT NULL,
        "issued_date" TEXT,
        "expiry_date" TEXT,
        "entry_date" TEXT,
        "exit_date" TEXT,
        "max_stay_days" INTEGER,
        "entry_rules" TEXT,
        "conditions" TEXT,
        "cost" REAL,
        "cost_currency" TEXT,
        "application_ref" TEXT,
        "notes" TEXT DEFAULT '',
        "photo_path" TEXT,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "expenses" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "trip_id" INTEGER,
        "title" TEXT NOT NULL,
        "category" TEXT NOT NULL,
        "amount" REAL NOT NULL,
        "currency" TEXT DEFAULT 'USD',
        "base_amount" REAL,
        "date" TEXT NOT NULL,
        "merchant" TEXT,
        "description" TEXT,
        "notes" TEXT,
        "tag" TEXT,
        "receipt_photo_path" TEXT,
        "trip_expense_id" INTEGER,
        "shared" INTEGER DEFAULT 0,
        "shared_with" TEXT,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "photos" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "trip_id" INTEGER,
        "file_path" TEXT NOT NULL,
        "thumbnail_path" TEXT,
        "caption" TEXT DEFAULT '',
        "tags" TEXT DEFAULT '',
        "captured_at" TEXT NOT NULL,
        "is_selfie" INTEGER DEFAULT 0,
        "people_count" INTEGER,
        "lat" REAL,
        "lon" REAL,
        "location_name" TEXT,
        "file_size" INTEGER DEFAULT 0,
        "width" INTEGER DEFAULT 0,
        "height" INTEGER DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "packing_items" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "trip_id" INTEGER,
        "category" TEXT NOT NULL,
        "name" TEXT NOT NULL,
        "quantity" INTEGER DEFAULT 1,
        "unit" TEXT,
        "packed" INTEGER DEFAULT 0,
        "essential" INTEGER DEFAULT 0,
        "notes" TEXT,
        "packed_by" INTEGER,
        "packed_at_minutes" INTEGER DEFAULT 0,
        "packed_now" INTEGER DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "notes" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "trip_id" TEXT,
        "title" TEXT NOT NULL,
        "content" TEXT NOT NULL,
        "tags" TEXT DEFAULT '',
        "category" TEXT,
        "priority" INTEGER DEFAULT 0,
        "is_pinned" INTEGER DEFAULT 0,
        "is_archived" INTEGER DEFAULT 0,
        "color" TEXT,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "reminder_at" TEXT,
        "reminder_set" INTEGER DEFAULT 0,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "task_projects" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "description" TEXT,
        "color" TEXT,
        "icon" TEXT,
        "order_index" INTEGER DEFAULT 0,
        "is_active" INTEGER DEFAULT 1,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "tasks" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "project_id" INTEGER,
        "title" TEXT NOT NULL,
        "description" TEXT,
        "details" TEXT,
        "status" INTEGER DEFAULT 0,
        "priority" INTEGER DEFAULT 1,
        "order_index" INTEGER DEFAULT 0,
        "due_date" TEXT,
        "started_at" TEXT,
        "completed_at" TEXT,
        "tag" TEXT,
        "tags" TEXT DEFAULT '',
        "category" TEXT,
        "is_recurring" INTEGER DEFAULT 0,
        "recurrence_pattern" TEXT,
        "recurrence_interval" INTEGER DEFAULT 1,
        "reminder_type" TEXT,
        "reminder_minutes_before" INTEGER,
        "notification_sent" INTEGER DEFAULT 0,
        "completed_by" TEXT,
        "depends_on" TEXT,
        "estimated_minutes" INTEGER,
        "actual_minutes" INTEGER,
        "is_quick" INTEGER DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "app_files" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "trip_id" INTEGER,
        "task_id" INTEGER,
        "note_id" INTEGER,
        "name" TEXT NOT NULL,
        "type" TEXT NOT NULL,
        "mime_type" TEXT NOT NULL,
        "file_path" TEXT NOT NULL,
        "thumbnail_path" TEXT,
        "file_size" INTEGER DEFAULT 0,
        "width" INTEGER,
        "height" INTEGER,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "folder_id" TEXT,
        "category" TEXT,
        "description" TEXT,
        "tags" TEXT DEFAULT '',
        "byte_count" INTEGER,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "folders" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "name" TEXT NOT NULL,
        "parent_id" TEXT,
        "color" TEXT,
        "icon" TEXT,
        "order_index" INTEGER DEFAULT 0,
        "file_count" INTEGER DEFAULT 0,
        "created_at" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL,
        "sync_status" INTEGER DEFAULT 0,
        "sync_enabled" INTEGER DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "sync_log" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "device_id" TEXT NOT NULL,
        "direction" TEXT NOT NULL,
        "module" TEXT NOT NULL,
        "action" TEXT NOT NULL,
        "record_id" INTEGER NOT NULL,
        "table_name" TEXT NOT NULL,
        "record_data" TEXT,
        "error" TEXT,
        "synced_at" TEXT NOT NULL,
        "server_response_time" INTEGER,
        "success" INTEGER DEFAULT 1,
        "retry_count" INTEGER,
        "last_retry" TEXT,
        "sync_batch_id" TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS "app_settings" (
        "id" INTEGER PRIMARY KEY AUTOINCREMENT,
        "key" TEXT NOT NULL UNIQUE,
        "value" TEXT NOT NULL,
        "updated_at" TEXT NOT NULL
      )
    ''');
  }

  // Generic CRUD operations
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table,
      {String? where, List<Object?>? whereArgs, String? orderBy, int? limit}) async {
    final db = await database;
    return db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<Map<String, dynamic>?> queryOne(String table,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    final results = await db.query(table, where: where, whereArgs: whereArgs, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> update(String table, Map<String, dynamic> data,
      {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<Object?>? args]) async {
    final db = await database;
    return db.rawQuery(sql, args);
  }

  // ---------- hotel CRUD ----------
  Future<int> insertHotel(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('hotels', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateHotel(int id, Map<String, dynamic> data) async {
    final db = await database;
    return db.update('hotels', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHotel(int id) async {
    final db = await database;
    return db.delete('hotels', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getHotelsForTrip(int tripId) async {
    final db = await database;
    return db.query('hotels', where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'check_in DESC');
  }

  /// Loads a trip with all of its related rows attached (hotels, flights,
  /// itinerary days + activities, packing items). One place so every screen
  /// gets accurate counts instead of empty lists.
  Future<Trip> loadTripRelations(Trip trip) async {
    final id = trip.id;
    if (id == null) return trip;

    final db = await database;

    final hotels = (await db.query('hotels', where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id], orderBy: 'check_in ASC'))
        .map(Hotel.fromMap)
        .toList();

    final flights = (await db.query('flights', where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id], orderBy: 'departure ASC'))
        .map(Flight.fromMap)
        .toList();

    final days = (await db.query('itinerary_days', where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id], orderBy: 'day_number ASC'))
        .map(ItineraryDay.fromMap)
        .toList();

    final activities = (await db.query('itinerary_activities', where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id], orderBy: 'start_time ASC'))
        .map(ItineraryActivity.fromMap)
        .toList();

    final packing = (await db.query('packing_items', where: 'trip_id = ? AND deleted_at IS NULL', whereArgs: [id], orderBy: 'category ASC, name ASC'))
        .map(PackingItem.fromMap)
        .toList();

    return trip.attachRelations(
      hotels: hotels,
      flights: flights,
      itineraryDays: days,
      packingItems: packing,
      activities: activities,
    );
  }

  /// Loads every trip with relations attached.
  Future<List<Trip>> loadTripsWithRelations({String? orderBy = 'departure ASC'}) async {
    final db = await database;
    final rows = await db.query(
      'trips',
      where: 'deleted_at IS NULL',
      orderBy: orderBy,
    );
    final trips = rows.map(Trip.fromMap).toList();
    return [for (final trip in trips) await loadTripRelations(trip)];
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) await db.close();
  }
}
