import 'package:sqflite/sqflite.dart';

class Expense {
  final int? id;
  final int? tripId;
  final String title;
  final String category;
  final double amount;
  final String currency;
  final double? baseAmount; // converted to trip base currency
  final DateTime date;
  final String? merchant;
  final String? description;
  final String? notes;
  final String? tag;
  final String? receiptPhotoPath;
  final int? tripExpenseId; // link to trip_expenses if part of a trip
  final bool shared;
  final String? sharedWith;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Expense({
    this.id,
    this.tripId,
    required this.title,
    required this.category,
    required this.amount,
    this.currency = 'USD',
    this.baseAmount,
    required this.date,
    this.merchant,
    this.description,
    this.notes,
    this.tag,
    this.receiptPhotoPath,
    this.tripExpenseId,
    this.shared = false,
    this.sharedWith,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'title': title,
        'category': category,
        'amount': amount,
        'currency': currency,
        'base_amount': baseAmount,
        'date': date.toIso8601String(),
        'merchant': merchant,
        'description': description,
        'notes': notes,
        'tag': tag,
        'receipt_photo_path': receiptPhotoPath,
        'trip_expense_id': tripExpenseId,
        'shared': shared ? 1 : 0,
        'shared_with': sharedWith,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int?,
        title: map['title'] as String,
        category: map['category'] as String,
        amount: map['amount'] as double,
        currency: map['currency'] as String? ?? 'USD',
        baseAmount: map['base_amount'] as double?,
        date: DateTime.parse(map['date'] as String),
        merchant: map['merchant'] as String?,
        description: map['description'] as String?,
        notes: map['notes'] as String?,
        tag: map['tag'] as String?,
        receiptPhotoPath: map['receipt_photo_path'] as String?,
        tripExpenseId: map['trip_expense_id'] as int?,
        shared: (map['shared'] as int? ?? 0) == 1,
        sharedWith: map['shared_with'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Expense copyWith({
    int? id,
    int? tripId,
    String? title,
    String? category,
    double? amount,
    String? currency,
    double? baseAmount,
    DateTime? date,
    String? merchant,
    String? description,
    String? notes,
    String? tag,
    String? receiptPhotoPath,
    int? tripExpenseId,
    bool? shared,
    String? sharedWith,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      baseAmount: baseAmount ?? this.baseAmount,
      date: date ?? this.date,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      tag: tag ?? this.tag,
      receiptPhotoPath: receiptPhotoPath ?? this.receiptPhotoPath,
      tripExpenseId: tripExpenseId ?? this.tripExpenseId,
      shared: shared ?? this.shared,
      sharedWith: sharedWith ?? this.sharedWith,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
