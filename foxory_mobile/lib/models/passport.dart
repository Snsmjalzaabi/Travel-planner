import 'package:sqflite/sqflite.dart';

class Passport {
  final int? id;
  final String passportNumber;
  final String country;
  final String countryCode; // ISO 3166-1 alpha-2
  final DateTime issuedDate;
  final DateTime expiryDate;
  final String issuingAuthority;
  final String holderName;
  final String? nationality;
  final String? placeOfBirth;
  final String? dateOfBirth;
  final String? taxId; // e.g., SIN, SSN, TIN
  final String photoPath; // path to photo of passport
  final String notes;
  final int expiryAlertMonths; // alert N months before expiry
  final bool expired;
  final bool expiringSoon;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Passport({
    this.id,
    required this.passportNumber,
    required this.country,
    required this.countryCode,
    required this.issuedDate,
    required this.expiryDate,
    this.issuingAuthority = '',
    this.holderName = '',
    this.nationality,
    this.placeOfBirth,
    this.dateOfBirth,
    this.taxId,
    this.photoPath = '',
    this.notes = '',
    this.expiryAlertMonths = 6,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        expired = expiryDate.isBefore(DateTime.now()),
        expiringSoon = expiryDate.difference(DateTime.now()).inDays <= expiryAlertMonths * 30 && expiryDate.isAfter(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'passport_number': passportNumber,
        'country': country,
        'country_code': countryCode,
        'issued_date': issuedDate.toIso8601String(),
        'expiry_date': expiryDate.toIso8601String(),
        'issuing_authority': issuingAuthority,
        'holder_name': holderName,
        'nationality': nationality,
        'place_of_birth': placeOfBirth,
        'date_of_birth': dateOfBirth,
        'tax_id': taxId,
        'photo_path': photoPath,
        'notes': notes,
        'expiry_alert_months': expiryAlertMonths,
        'expired': expired ? 1 : 0,
        'expiring_soon': expiringSoon ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Passport.fromMap(Map<String, dynamic> map) => Passport(
        id: map['id'] as int?,
        passportNumber: map['passport_number'] as String,
        country: map['country'] as String,
        countryCode: map['country_code'] as String,
        issuedDate: DateTime.parse(map['issued_date'] as String),
        expiryDate: DateTime.parse(map['expiry_date'] as String),
        issuingAuthority: map['issuing_authority'] as String? ?? '',
        holderName: map['holder_name'] as String? ?? '',
        nationality: map['nationality'] as String?,
        placeOfBirth: map['place_of_birth'] as String?,
        dateOfBirth: map['date_of_birth'] as String?,
        taxId: map['tax_id'] as String?,
        photoPath: map['photo_path'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
        expiryAlertMonths: map['expiry_alert_months'] as int? ?? 6,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Passport copyWith({
    int? id,
    String? passportNumber,
    String? country,
    String? countryCode,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? issuingAuthority,
    String? holderName,
    String? nationality,
    String? placeOfBirth,
    String? dateOfBirth,
    String? taxId,
    String? photoPath,
    String? notes,
    int? expiryAlertMonths,
    bool? expired,
    bool? expiringSoon,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Passport(
      id: id ?? this.id,
      passportNumber: passportNumber ?? this.passportNumber,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      issuingAuthority: issuingAuthority ?? this.issuingAuthority,
      holderName: holderName ?? this.holderName,
      nationality: nationality ?? this.nationality,
      placeOfBirth: placeOfBirth ?? this.placeOfBirth,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      taxId: taxId ?? this.taxId,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      expiryAlertMonths: expiryAlertMonths ?? this.expiryAlertMonths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}

class Visa {
  final int? id;
  final int? passportId;
  final String country;
  final String countryCode;
  final String visaType; // tourist, business, transit, student, work, resident, other
  final String status; // applied, approved, rejected, not_required, pending, expired
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final DateTime? entryDate;
  final DateTime? exitDate;
  final int? maxStayDays;
  final String? entryRules; // e.g., "Multiple entry", "Single entry"
  final String? conditions;
  final double? cost;
  final String? costCurrency;
  final String? applicationRef;
  final String? notes;
  final String photoPath; // visa sticker/photo
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Visa({
    this.id,
    this.passportId,
    required this.country,
    required this.countryCode,
    required this.visaType,
    required this.status,
    this.issuedDate,
    this.expiryDate,
    this.entryDate,
    this.exitDate,
    this.maxStayDays,
    this.entryRules,
    this.conditions,
    this.cost,
    this.costCurrency,
    this.applicationRef,
    this.notes,
    this.photoPath = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isValid =>
      status == 'approved' &&
      expiryDate != null &&
      expiryDate!.isAfter(DateTime.now());

  bool get expired => status == 'approved' && expiryDate != null && expiryDate!.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'passport_id': passportId,
        'country': country,
        'country_code': countryCode,
        'visa_type': visaType,
        'status': status,
        'issued_date': issuedDate?.toIso8601String(),
        'expiry_date': expiryDate?.toIso8601String(),
        'entry_date': entryDate?.toIso8601String(),
        'exit_date': exitDate?.toIso8601String(),
        'max_stay_days': maxStayDays,
        'entry_rules': entryRules,
        'conditions': conditions,
        'cost': cost,
        'cost_currency': costCurrency,
        'application_ref': applicationRef,
        'notes': notes,
        'photo_path': photoPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Visa.fromMap(Map<String, dynamic> map) => Visa(
        id: map['id'] as int?,
        passportId: map['passport_id'] as int?,
        country: map['country'] as String,
        countryCode: map['country_code'] as String,
        visaType: map['visa_type'] as String,
        status: map['status'] as String,
        issuedDate: map['issued_date'] != null
            ? DateTime.parse(map['issued_date'] as String)
            : null,
        expiryDate: map['expiry_date'] != null
            ? DateTime.parse(map['expiry_date'] as String)
            : null,
        entryDate: map['entry_date'] != null
            ? DateTime.parse(map['entry_date'] as String)
            : null,
        exitDate: map['exit_date'] != null
            ? DateTime.parse(map['exit_date'] as String)
            : null,
        maxStayDays: map['max_stay_days'] as int?,
        entryRules: map['entry_rules'] as String?,
        conditions: map['conditions'] as String?,
        cost: map['cost'] as double?,
        costCurrency: map['cost_currency'] as String?,
        applicationRef: map['application_ref'] as String?,
        notes: map['notes'] as String? ?? '',
        photoPath: map['photo_path'] as String? ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Visa copyWith({
    int? id,
    int? passportId,
    String? country,
    String? countryCode,
    String? visaType,
    String? status,
    DateTime? issuedDate,
    DateTime? expiryDate,
    DateTime? entryDate,
    DateTime? exitDate,
    int? maxStayDays,
    String? entryRules,
    String? conditions,
    double? cost,
    String? costCurrency,
    String? applicationRef,
    String? notes,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Visa(
      id: id ?? this.id,
      passportId: passportId ?? this.passportId,
      country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode,
      visaType: visaType ?? this.visaType,
      status: status ?? this.status,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      entryDate: entryDate ?? this.entryDate,
      exitDate: exitDate ?? this.exitDate,
      maxStayDays: maxStayDays ?? this.maxStayDays,
      entryRules: entryRules ?? this.entryRules,
      conditions: conditions ?? this.conditions,
      cost: cost ?? this.cost,
      costCurrency: costCurrency ?? this.costCurrency,
      applicationRef: applicationRef ?? this.applicationRef,
      notes: notes ?? this.notes,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
