import 'package:sqflite/sqflite.dart';

class Visa {
  final int? id;
  final int? passportId;
  final String country;
  final String visaType;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? visaNumber;
  final String? notes;
  final String? status; // granted, pending, refused, not_required

  Visa({
    this.id,
    this.passportId,
    required this.country,
    required this.visaType,
    this.issueDate,
    this.expiryDate,
    this.visaNumber,
    this.notes,
    this.status,
  });

  factory Visa.fromMap(Map<String, dynamic> map) {
    return Visa(
      id: map['id'] as int?,
      passportId: map['passport_id'] as int?,
      country: map['country'] as String,
      visaType: map['visa_type'] as String,
      issueDate: map['issue_date'] != null ? DateTime.parse(map['issue_date'] as String) : null,
      expiryDate: map['expiry_date'] != null ? DateTime.parse(map['expiry_date'] as String) : null,
      visaNumber: map['visa_number'] as String?,
      notes: map['notes'] as String?,
      status: map['status'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'passport_id': passportId,
      'country': country,
      'visa_type': visaType,
      'issue_date': issueDate?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'visa_number': visaNumber,
      'notes': notes,
      'status': status ?? 'not_required',
    };
  }

  Visa copyWith({
    int? id,
    int? passportId,
    String? country,
    String? visaType,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? visaNumber,
    String? notes,
    String? status,
  }) {
    return Visa(
      id: id ?? this.id,
      passportId: passportId ?? this.passportId,
      country: country ?? this.country,
      visaType: visaType ?? this.visaType,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      visaNumber: visaNumber ?? this.visaNumber,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

class VisaDao {
  static String createTable() {
    return '''
    CREATE TABLE IF NOT EXISTS visas (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      passport_id INTEGER,
      country TEXT NOT NULL,
      visa_type TEXT NOT NULL,
      issue_date TEXT,
      expiry_date TEXT,
      visa_number TEXT,
      notes TEXT,
      status TEXT DEFAULT 'not_required',
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY (passport_id) REFERENCES passports(id) ON DELETE SET NULL
    )
    ''';
  }

  static Future<int> insert(Database db, Visa visa) async {
    return db.insert('visas', {
      'passport_id': visa.passportId,
      'country': visa.country,
      'visa_type': visa.visaType,
      'issue_date': visa.issueDate?.toIso8601String(),
      'expiry_date': visa.expiryDate?.toIso8601String(),
      'visa_number': visa.visaNumber,
      'notes': visa.notes,
      'status': visa.status ?? 'not_required',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAll(Database db) async {
    return db.query('visas', orderBy: 'country ASC');
  }

  static Future<Map<String, dynamic>?> getById(Database db, int id) async {
    final results = await db.query('visas', where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  static Future<List<Map<String, dynamic>>> getByPassport(Database db, int passportId) async {
    return db.query('visas', where: 'passport_id = ?', whereArgs: [passportId]);
  }

  static Future<int> update(Database db, Visa visa) async {
    return db.update('visas', {
      'passport_id': visa.passportId,
      'country': visa.country,
      'visa_type': visa.visaType,
      'issue_date': visa.issueDate?.toIso8601String(),
      'expiry_date': visa.expiryDate?.toIso8601String(),
      'visa_number': visa.visaNumber,
      'notes': visa.notes,
      'status': visa.status,
      'updated_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [visa.id]);
  }

  static Future<int> delete(Database db, int id) async {
    return db.delete('visas', where: 'id = ?', whereArgs: [id]);
  }
}
