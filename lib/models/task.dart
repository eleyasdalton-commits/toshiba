enum TaskPriority { high, medium, low }

/// How the task is scheduled — mirrors the SRS requirement that tasks can be
/// filed under an hour, day, week, month, or year.
enum TaskScope { hourly, daily, weekly, monthly, yearly }

class AppTask {
  final String id;
  String title;
  String category;
  TaskPriority priority;
  TaskScope scope;
  DateTime dueAt;
  bool isCompleted;
  DateTime? completedAt;
  DateTime? alarmAt;
  String? alarmSound;

  AppTask({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.scope,
    required this.dueAt,
    this.isCompleted = false,
    this.completedAt,
    this.alarmAt,
    this.alarmSound,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'priority': priority.name,
        'scope': scope.name,
        'dueAt': dueAt.toIso8601String(),
        'isCompleted': isCompleted ? 1 : 0,
        'completedAt': completedAt?.toIso8601String(),
        'alarmAt': alarmAt?.toIso8601String(),
        'alarmSound': alarmSound,
      };

  factory AppTask.fromMap(Map<String, dynamic> map) => AppTask(
        id: map['id'] as String,
        title: map['title'] as String,
        category: map['category'] as String,
        priority: TaskPriority.values.byName(map['priority'] as String),
        scope: TaskScope.values.byName(map['scope'] as String),
        dueAt: DateTime.parse(map['dueAt'] as String),
        isCompleted: (map['isCompleted'] as int) == 1,
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'] as String)
            : null,
        alarmAt: map['alarmAt'] != null
            ? DateTime.parse(map['alarmAt'] as String)
            : null,
        alarmSound: map['alarmSound'] as String?,
      );
}
