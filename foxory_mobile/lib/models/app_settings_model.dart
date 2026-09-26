import 'package:sqflite/sqflite.dart';

class AppSettingsModel {
  final int? id;
  final String key;
  final String value;
  final DateTime updatedAt;

  AppSettingsModel({
    this.id,
    required this.key,
    required this.value,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'value': value,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory AppSettingsModel.fromMap(Map<String, dynamic> map) => AppSettingsModel(
        id: map['id'] as int,
        key: map['key'] as String,
        value: map['value'] as String,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  static const String createTable = '''
    CREATE TABLE IF NOT EXISTS "app_settings" (
      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
      "key" TEXT NOT NULL UNIQUE,
      "value" TEXT NOT NULL,
      "updated_at" TEXT NOT NULL
    )
  ''';
}
