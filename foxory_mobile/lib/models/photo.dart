
class Photo {
  final int? id;
  final int? tripId;
  final String filePath;
  final String thumbnailPath;
  final String caption;
  final List<String> tags;
  final DateTime capturedAt;
  final bool isSelfie;
  final int? peopleCount;
  final double? lat;
  final double? lon;
  final String? locationName;
  final int fileSize;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Photo({
    this.id,
    this.tripId,
    required this.filePath,
    this.thumbnailPath = '',
    this.caption = '',
    List<String>? tags,
    required this.capturedAt,
    this.isSelfie = false,
    this.peopleCount,
    this.lat,
    this.lon,
    this.locationName,
    this.fileSize = 0,
    this.width = 0,
    this.height = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'caption': caption,
        'tags': tags.join(','),
        'captured_at': capturedAt.toIso8601String(),
        'is_selfie': isSelfie ? 1 : 0,
        'people_count': peopleCount,
        'lat': lat,
        'lon': lon,
        'location_name': locationName,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Photo.fromMap(Map<String, dynamic> map) => Photo(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int?,
        filePath: map['file_path'] as String,
        thumbnailPath: map['thumbnail_path'] as String? ?? '',
        caption: map['caption'] as String? ?? '',
        tags: (map['tags'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        capturedAt: DateTime.parse(map['captured_at'] as String),
        isSelfie: (map['is_selfie'] as int? ?? 0) == 1,
        peopleCount: map['people_count'] as int?,
        lat: map['lat'] as double?,
        lon: map['lon'] as double?,
        locationName: map['location_name'] as String?,
        fileSize: map['file_size'] as int? ?? 0,
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Photo copyWith({
    int? id,
    int? tripId,
    String? filePath,
    String? thumbnailPath,
    String? caption,
    List<String>? tags,
    DateTime? capturedAt,
    bool? isSelfie,
    int? peopleCount,
    double? lat,
    double? lon,
    String? locationName,
    int? fileSize,
    int? width,
    int? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Photo(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      filePath: filePath ?? this.filePath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      capturedAt: capturedAt ?? this.capturedAt,
      isSelfie: isSelfie ?? this.isSelfie,
      peopleCount: peopleCount ?? this.peopleCount,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      locationName: locationName ?? this.locationName,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
