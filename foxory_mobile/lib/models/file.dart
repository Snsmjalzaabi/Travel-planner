
class AppFile {
  final int? id;
  final int? tripId;
  final int? taskId;
  final int? noteId;
  final String name;
  final String type; // image, document, pdf, audio, video, other
  final String mimeType;
  final String filePath;
  final String? thumbnailPath;
  final int fileSize;
  final int? width;
  final int? height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? folderId;
  final String? category;
  final String? description;
  final List<String> tags;
  final int? byteCount;
  final int syncStatus;
  final bool syncEnabled;

  AppFile({
    this.id,
    this.tripId,
    this.taskId,
    this.noteId,
    required this.name,
    required this.type,
    required this.mimeType,
    required this.filePath,
    this.thumbnailPath,
    this.fileSize = 0,
    this.width,
    this.height,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.folderId,
    this.category,
    this.description,
    List<String>? tags,
    this.byteCount,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'task_id': taskId,
        'note_id': noteId,
        'name': name,
        'type': type,
        'mime_type': mimeType,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'folder_id': folderId,
        'category': category,
        'description': description,
        'tags': tags.join(','),
        'byte_count': byteCount,
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory AppFile.fromMap(Map<String, dynamic> map) => AppFile(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int?,
        taskId: map['task_id'] as int?,
        noteId: map['note_id'] as int?,
        name: map['name'] as String,
        type: map['type'] as String,
        mimeType: map['mime_type'] as String,
        filePath: map['file_path'] as String,
        thumbnailPath: map['thumbnail_path'] as String?,
        fileSize: map['file_size'] as int? ?? 0,
        width: map['width'] as int?,
        height: map['height'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        folderId: map['folder_id'] as String?,
        category: map['category'] as String?,
        description: map['description'] as String?,
        tags: (map['tags'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        byteCount: map['byte_count'] as int?,
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  AppFile copyWith({
    int? id,
    int? tripId,
    int? taskId,
    int? noteId,
    String? name,
    String? type,
    String? mimeType,
    String? filePath,
    String? thumbnailPath,
    int? fileSize,
    int? width,
    int? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? folderId,
    String? category,
    String? description,
    List<String>? tags,
    int? byteCount,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return AppFile(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      taskId: taskId ?? this.taskId,
      noteId: noteId ?? this.noteId,
      name: name ?? this.name,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      folderId: folderId ?? this.folderId,
      category: category ?? this.category,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      byteCount: byteCount ?? this.byteCount,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}

class Folder {
  final int? id;
  final String name;
  final String? parentId;
  final String? color;
  final String? icon;
  final int orderIndex;
  final int fileCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Folder({
    this.id,
    required this.name,
    this.parentId,
    this.color,
    this.icon,
    this.orderIndex = 0,
    this.fileCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'parent_id': parentId,
        'color': color,
        'icon': icon,
        'order_index': orderIndex,
        'file_count': fileCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Folder.fromMap(Map<String, dynamic> map) => Folder(
        id: map['id'] as int?,
        name: map['name'] as String,
        parentId: map['parent_id'] as String?,
        color: map['color'] as String?,
        icon: map['icon'] as String?,
        orderIndex: map['order_index'] as int? ?? 0,
        fileCount: map['file_count'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Folder copyWith({
    int? id,
    String? name,
    String? parentId,
    String? color,
    String? icon,
    int? orderIndex,
    int? fileCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Folder(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      orderIndex: orderIndex ?? this.orderIndex,
      fileCount: fileCount ?? this.fileCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
