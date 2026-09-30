
class PackingItem {
  final int? id;
  final int? tripId;
  final String category;
  final String name;
  final int quantity;
  final String unit;
  final bool packed;
  final bool essential;
  final String? notes;
  final int? packedBy; // user ID if multiple travelers
  final int packedAtMinutes; // minutes before departure to pack
  final bool packedNow;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  PackingItem({
    this.id,
    this.tripId,
    required this.category,
    required this.name,
    this.quantity = 1,
    this.unit = '',
    this.packed = false,
    this.essential = false,
    this.notes,
    this.packedBy,
    this.packedAtMinutes = 0,
    this.packedNow = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'trip_id': tripId,
        'category': category,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'packed': packed ? 1 : 0,
        'essential': essential ? 1 : 0,
        'notes': notes,
        'packed_by': packedBy,
        'packed_at_minutes': packedAtMinutes,
        'packed_now': packedNow ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory PackingItem.fromMap(Map<String, dynamic> map) => PackingItem(
        id: map['id'] as int?,
        tripId: map['trip_id'] as int?,
        category: map['category'] as String,
        name: map['name'] as String,
        quantity: map['quantity'] as int? ?? 1,
        unit: map['unit'] as String? ?? '',
        packed: (map['packed'] as int? ?? 0) == 1,
        essential: (map['essential'] as int? ?? 0) == 1,
        notes: map['notes'] as String?,
        packedBy: map['packed_by'] as int?,
        packedAtMinutes: map['packed_at_minutes'] as int? ?? 0,
        packedNow: (map['packed_now'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  PackingItem copyWith({
    int? id,
    int? tripId,
    String? category,
    String? name,
    int? quantity,
    String? unit,
    bool? packed,
    bool? essential,
    String? notes,
    int? packedBy,
    int? packedAtMinutes,
    bool? packedNow,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return PackingItem(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      packed: packed ?? this.packed,
      essential: essential ?? this.essential,
      notes: notes ?? this.notes,
      packedBy: packedBy ?? this.packedBy,
      packedAtMinutes: packedAtMinutes ?? this.packedAtMinutes,
      packedNow: packedNow ?? this.packedNow,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }

  // Pre-built packing templates
  static List<PackingItem> beachTripTemplate({int? tripId}) => [
        PackingItem(category: 'Clothes', name: 'Swimwear', quantity: 2, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'T-shirts', quantity: 5, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Shorts', quantity: 3, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Sunglasses', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Toiletries', name: 'Sunscreen SPF 50+', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Toiletries', name: 'After-sun lotion', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Sandals/flip-flops', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Waterproof phone pouch', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Portable charger', quantity: 1, tripId: tripId),
        PackingItem(category: 'Documents', name: 'Passport + copies', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Health', name: 'Insect repellent', quantity: 1, tripId: tripId),
        PackingItem(category: 'Misc', name: 'Beach towel', quantity: 1, tripId: tripId),
        PackingItem(category: 'Misc', name: 'Dry bag', quantity: 1, tripId: tripId),
      ];

  static List<PackingItem> cityBreakTemplate({int? tripId}) => [
        PackingItem(category: 'Clothes', name: 'Comfortable walking shoes', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Smart-casual outfits', quantity: 3, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Light jacket/cardigan', quantity: 1, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Umbrella or compact rain coat', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Travel-sized toiletries', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Deodorant', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Moisturizer', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Power bank', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Universal adapter', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Tech', name: 'Phone charger cable', quantity: 1, tripId: tripId),
        PackingItem(category: 'Documents', name: 'Passport/ID', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Documents', name: 'Wallet + cards + cash', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Health', name: 'Basic first aid kit', quantity: 1, tripId: tripId),
        PackingItem(category: 'Health', name: 'Painkillers', quantity: 1, tripId: tripId),
        PackingItem(category: 'Misc', name: 'Reusable water bottle', quantity: 1, tripId: tripId),
        PackingItem(category: 'Misc', name: 'Daypack', quantity: 1, tripId: tripId),
      ];

  static List<PackingItem> businessTemplate({int? tripId}) => [
        PackingItem(category: 'Clothes', name: 'Suit/blazer', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Dress shirts', quantity: 3, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Trousers/slacks', quantity: 2, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Dress shoes', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Casual outfits (evenings)', quantity: 2, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Dental kit', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Razor + shaving kit', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Grooming items', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Laptop + charger', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Tech', name: 'Noise-cancelling headphones', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Power bank', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Universal adapter', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Documents', name: 'Passport + boarding passes', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Documents', name: 'Business cards', quantity: 1, tripId: tripId),
        PackingItem(category: 'Documents', name: 'Meeting notes + agenda', quantity: 1, tripId: tripId),
        PackingItem(category: 'Health', name: 'Prescription meds', quantity: 1, tripId: tripId, essential: true),
      ];

  static List<PackingItem> hikingCampingTemplate({int? tripId}) => [
        PackingItem(category: 'Clothes', name: 'Hiking boots', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Trail shoes/sneakers', quantity: 1, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Moisture-wicking t-shirts', quantity: 3, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Insulating layer (fleece/jacket)', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Waterproof jacket', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Clothes', name: 'Quick-dry hiking pants', quantity: 2, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Thermal base layer', quantity: 1, tripId: tripId),
        PackingItem(category: 'Clothes', name: 'Wool socks (3 pairs)', quantity: 3, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Biodegradable soap', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Sunscreen', quantity: 1, tripId: tripId),
        PackingItem(category: 'Toiletries', name: 'Lip balm with SPF', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'Headlamp/flashlight + spare batteries', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Tech', name: 'Power bank', quantity: 1, tripId: tripId),
        PackingItem(category: 'Tech', name: 'GPS device or offline maps', quantity: 1, tripId: tripId),
        PackingItem(category: 'Documents', name: 'Passport/ID + copies', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Documents', name: 'Camping permit (if required)', quantity: 1, tripId: tripId),
        PackingItem(category: 'Health', name: 'First aid kit (comprehensive)', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Health', name: 'Blister plasters', quantity: 1, tripId: tripId),
        PackingItem(category: 'Health', name: 'Altitude sickness meds (if needed)', quantity: 1, tripId: tripId),
        PackingItem(category: 'Camping', name: 'Tent', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Camping', name: 'Sleeping bag', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Camping', name: 'Sleeping pad', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Camping', name: 'Camping stove + fuel', quantity: 1, tripId: tripId),
        PackingItem(category: 'Camping', name: 'Cookware + utensils', quantity: 1, tripId: tripId),
        PackingItem(category: 'Camping', name: 'Water bottles/filter (3L capacity)', quantity: 1, tripId: tripId, essential: true),
        PackingItem(category: 'Camping', name: 'Food (meals + snacks)', quantity: 1, tripId: tripId),
        PackingItem(category: 'Camping', name: 'Cash (no signal areas)', quantity: 1, tripId: tripId),
      ];
}
