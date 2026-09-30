
enum TaskStatus { todo, inProgress, done }
enum TaskPriority { low, medium, high }

class TaskProject {
  final int? id;
  final String name;
  final String? description;
  final String? color;
  final String? icon;
  final int orderIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  TaskProject({
    this.id,
    required this.name,
    this.description,
    this.color,
    this.icon,
    this.orderIndex = 0,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'color': color,
        'icon': icon,
        'order_index': orderIndex,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory TaskProject.fromMap(Map<String, dynamic> map) => TaskProject(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
        color: map['color'] as String?,
        icon: map['icon'] as String?,
        orderIndex: map['order_index'] as int? ?? 0,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  TaskProject copyWith({
    int? id,
    String? name,
    String? description,
    String? color,
    String? icon,
    int? orderIndex,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return TaskProject(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}

class Task {
  final int? id;
  final int? projectId;
  final String title;
  final String? description;
  final String? details;
  final TaskStatus status;
  final TaskPriority priority;
  final int orderIndex;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? tag;
  final List<String> tags;
  final String? category;
  final bool isRecurring;
  final String? recurrencePattern; // daily, weekly, monthly
  final int recurrenceInterval;
  final String? reminderType; // notification, email, sms
  final int? reminderMinutesBefore;
  final bool notificationSent;
  final String? completedBy;
  final String? dependsOn; // IDs of tasks this depends on
  final int? estimatedMinutes;
  final int? actualMinutes;
  final bool isQuick;
  final bool isCompleted;
  final bool isOverdue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncStatus;
  final bool syncEnabled;

  Task({
    this.id,
    this.projectId,
    required this.title,
    this.description,
    this.details,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.medium,
    this.orderIndex = 0,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    this.tag,
    List<String>? tags,
    this.category,
    this.isRecurring = false,
    this.recurrencePattern,
    this.recurrenceInterval = 1,
    this.reminderType,
    this.reminderMinutesBefore,
    this.notificationSent = false,
    this.completedBy,
    this.dependsOn,
    this.estimatedMinutes,
    this.actualMinutes,
    this.isQuick = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 0,
    this.syncEnabled = true,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        isCompleted = status == TaskStatus.done,
        isOverdue = status != TaskStatus.done &&
            dueDate != null &&
            dueDate.isBefore(DateTime.now());

  Map<String, dynamic> toMap() => {
        'id': id,
        'project_id': projectId,
        'title': title,
        'description': description,
        'details': details,
        'status': status.index,
        'priority': priority.index,
        'order_index': orderIndex,
        'due_date': dueDate?.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'tag': tag,
        'tags': tags.join(','),
        'category': category,
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_pattern': recurrencePattern,
        'recurrence_interval': recurrenceInterval,
        'reminder_type': reminderType,
        'reminder_minutes_before': reminderMinutesBefore,
        'notification_sent': notificationSent ? 1 : 0,
        'completed_by': completedBy,
        'depends_on': dependsOn,
        'estimated_minutes': estimatedMinutes,
        'actual_minutes': actualMinutes,
        'is_quick': isQuick ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'sync_status': syncStatus,
        'sync_enabled': syncEnabled ? 1 : 0,
      };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
        id: map['id'] as int?,
        projectId: map['project_id'] as int?,
        title: map['title'] as String,
        description: map['description'] as String?,
        details: map['details'] as String?,
        status: TaskStatus.values[map['status'] as int? ?? 0],
        priority: TaskPriority.values[map['priority'] as int? ?? 1],
        orderIndex: map['order_index'] as int? ?? 0,
        dueDate: map['due_date'] != null
            ? DateTime.parse(map['due_date'] as String)
            : null,
        startedAt: map['started_at'] != null
            ? DateTime.parse(map['started_at'] as String)
            : null,
        completedAt: map['completed_at'] != null
            ? DateTime.parse(map['completed_at'] as String)
            : null,
        tag: map['tag'] as String?,
        tags: (map['tags'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        category: map['category'] as String?,
        isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
        recurrencePattern: map['recurrence_pattern'] as String?,
        recurrenceInterval: map['recurrence_interval'] as int? ?? 1,
        reminderType: map['reminder_type'] as String?,
        reminderMinutesBefore: map['reminder_minutes_before'] as int?,
        notificationSent: (map['notification_sent'] as int? ?? 0) == 1,
        completedBy: map['completed_by'] as String?,
        dependsOn: map['depends_on'] as String?,
        estimatedMinutes: map['estimated_minutes'] as int?,
        actualMinutes: map['actual_minutes'] as int?,
        isQuick: (map['is_quick'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        syncStatus: map['sync_status'] as int? ?? 0,
        syncEnabled: (map['sync_enabled'] as int? ?? 1) == 1,
      );

  static const String createTable = '''
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
  ''';

  Task copyWith({
    int? id,
    int? projectId,
    String? title,
    String? description,
    String? details,
    TaskStatus? status,
    TaskPriority? priority,
    int? orderIndex,
    DateTime? dueDate,
    DateTime? startedAt,
    DateTime? completedAt,
    String? tag,
    List<String>? tags,
    String? category,
    bool? isRecurring,
    String? recurrencePattern,
    int? recurrenceInterval,
    String? reminderType,
    int? reminderMinutesBefore,
    bool? notificationSent,
    String? completedBy,
    String? dependsOn,
    int? estimatedMinutes,
    int? actualMinutes,
    bool? isQuick,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? syncStatus,
    bool? syncEnabled,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      details: details ?? this.details,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      orderIndex: orderIndex ?? this.orderIndex,
      dueDate: dueDate ?? this.dueDate,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      tag: tag ?? this.tag,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      reminderType: reminderType ?? this.reminderType,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
      notificationSent: notificationSent ?? this.notificationSent,
      completedBy: completedBy ?? this.completedBy,
      dependsOn: dependsOn ?? this.dependsOn,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      isQuick: isQuick ?? this.isQuick,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncEnabled: syncEnabled ?? this.syncEnabled,
    );
  }
}
