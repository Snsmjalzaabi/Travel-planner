import 'package:sqflite/sqflite.dart';

class Note {
  final int? id;
  final String? tripId;
  final String title;
  final String content;
  final List<String> tags;
  final String? category;
  final int? priority; // 0=low, 1=medium, 2=high
  final bool isPinned;
  final bool isArchived;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final bool reminderSet;
  final int syncStatus;
  final bool syncEnabled;

  Note({
    this.id,
    this.tripId,
    required this.title,
    required this.content,
    List<String>? tags,
    this.category,
    this.priority = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reminderAt,
    this.reminderSet = false,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get displayTitle => title.isEmpty ? 'Untitled' : title;

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'title': title,
        'content': content,
        'tags': tags.join(','),
        'category': category,
        'priority': priority,
        'is_pinned': isPinned ? 1 : 0,
        'is_archived': isArchived ? 1 : 0,
        'color': color,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'reminder_at': reminderAt?.toIso8601String(),
        'reminder_set': reminderSet ? 1 : 0,
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        tripId: map['trip_id'] as String?,
        title: map['title'] as String,
        content: map['content'] as String,
        tags: (map['tags'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        category: map['category'] as String?,
        priority: map['priority'] as int? ?? 0,
        isPinned: (map['is_pinned'] as int? ?? 0) == 1,
        isArchived: (map['is_archived'] as int? ?? 0) == 1,
        color: map['color'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        reminderAt: map['reminder_at'] != null
            ? DateTime.parse(map['reminder_at'] as String)
            : null,
        reminderSet: (map['reminder_set'] as int? ?? 0) == 1,
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Note copyWith({
    int? id,
    String? tripId,
    String? title,
    String? content,
    List<String>? tags,
    String? category,
    int? priority,
    bool? isPinned,
    bool? isArchived,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reminderAt,
    bool? reminderSet,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Note(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      reminderSet: reminderSet ?? this.reminderSet,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
