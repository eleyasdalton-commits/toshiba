class Habit {
  final String id;
  String name;
  String? category;
  int currentStreak;
  int bestStreak;
  DateTime? lastCompletedAt;
  DateTime? alarmAt;
  bool completedToday;
  DateTime createdAt;

  Habit({
    required this.id,
    required this.name,
    this.category,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedAt,
    this.alarmAt,
    this.completedToday = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastCompletedAt': lastCompletedAt?.toIso8601String(),
        'alarmAt': alarmAt?.toIso8601String(),
        'completedToday': completedToday ? 1 : 0,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromMap(Map<String, dynamic> map) => Habit(
        id: map['id'] as String,
        name: map['name'] as String,
        category: map['category'] as String?,
        currentStreak: map['currentStreak'] as int,
        bestStreak: map['bestStreak'] as int,
        lastCompletedAt: map['lastCompletedAt'] != null
            ? DateTime.parse(map['lastCompletedAt'] as String)
            : null,
        alarmAt: map['alarmAt'] != null
            ? DateTime.parse(map['alarmAt'] as String)
            : null,
        completedToday: (map['completedToday'] as int) == 1,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'] as String)
            : DateTime.now(),
      );

  /// Call once per day when the user marks the habit done. Handles the
  /// streak-counter logic described in the SRS (consecutive-day tracking).
  void markCompleted() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (lastCompletedAt != null) {
      final last = DateTime(
        lastCompletedAt!.year,
        lastCompletedAt!.month,
        lastCompletedAt!.day,
      );
      final gap = today.difference(last).inDays;
      if (gap == 1) {
        currentStreak += 1;
      } else if (gap > 1) {
        currentStreak = 1; // streak broken, restart
      }
      // gap == 0 → already completed today, no-op on streak
    } else {
      currentStreak = 1;
    }

    bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
    lastCompletedAt = now;
    completedToday = true;
  }

  /// Recomputes `currentStreak`, `bestStreak`, `lastCompletedAt` and
  /// `completedToday` from a full history of completion dates (from the
  /// `habit_completions` table). This is the source of truth used after any
  /// edit/undo, so streaks never drift out of sync with the actual history.
  static ({int current, int best, DateTime? last, bool today})
      computeStreaksFromHistory(List<DateTime> completionDays) {
    if (completionDays.isEmpty) {
      return (current: 0, best: 0, last: null, today: false);
    }
    final days = completionDays.toSet().toList()..sort();

    int best = 1;
    int running = 1;
    for (var i = 1; i < days.length; i++) {
      final gap = days[i].difference(days[i - 1]).inDays;
      if (gap == 1) {
        running += 1;
      } else if (gap > 1) {
        running = 1;
      }
      if (running > best) best = running;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final last = days.last;

    // Current streak only counts if it's still "alive" — last completion
    // was today or yesterday. Otherwise it has lapsed to 0.
    int current = 0;
    if (last == today || last == yesterday) {
      current = 1;
      for (var i = days.length - 1; i > 0; i--) {
        if (days[i].difference(days[i - 1]).inDays == 1) {
          current += 1;
        } else {
          break;
        }
      }
    }

    return (current: current, best: best, last: last, today: last == today);
  }
}
