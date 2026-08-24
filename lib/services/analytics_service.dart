import '../models/task.dart';
import 'database_service.dart';

/// One day's worth of chart-ready numbers.
class DailyStat {
  final DateTime day;
  final double score; // 0-100, same formula as ScoreService.dailyScore
  final int tasksCompleted;
  final int tasksTotal;
  final int habitsCompleted;
  final int habitsTotal;
  final int journalRatingSum; // 0-15

  DailyStat({
    required this.day,
    required this.score,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.habitsCompleted,
    required this.habitsTotal,
    required this.journalRatingSum,
  });
}

/// Builds the weekly/monthly performance history behind `StatsScreen`, using
/// the same 50/30/20 weighting as `ScoreService` but replayed day-by-day
/// over a date range instead of just "today".
class AnalyticsService {
  final _db = DatabaseService.instance;

  Future<List<DailyStat>> getDailyStats({
    required DateTime from,
    required DateTime to,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final tasks = await _db.getTasksInRange(start, end);
    final habits = await _db.getAllHabits();
    final completions = await _db.getHabitCompletionsInRange(start, end);
    final journalEntries = await _db.getJournalEntriesInRange(start, end);

    final tasksByDay = <DateTime, List<AppTask>>{};
    for (final t in tasks) {
      final d = DateTime(t.dueAt.year, t.dueAt.month, t.dueAt.day);
      tasksByDay.putIfAbsent(d, () => []).add(t);
    }

    final journalByDay = {for (final j in journalEntries) j.date: j};

    final stats = <DailyStat>[];
    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final dayTasks = tasksByDay[d] ?? const <AppTask>[];
      // Only count habits that existed by this day, so charts before a
      // habit was created aren't dragged down by it.
      final dayHabits = habits.where((h) {
        final created = DateTime(h.createdAt.year, h.createdAt.month, h.createdAt.day);
        return !created.isAfter(d);
      }).toList();
      final habitsCompleted = dayHabits
          .where((h) => (completions[h.id] ?? const []).any((c) =>
              c.year == d.year && c.month == d.month && c.day == d.day))
          .length;
      final journal = journalByDay[d];

      double taskComponent = 0;
      if (dayTasks.isNotEmpty) {
        final completed = dayTasks.where((t) => t.isCompleted).length;
        taskComponent = (completed / dayTasks.length) * 50;
      }
      double habitComponent = 0;
      if (dayHabits.isNotEmpty) {
        habitComponent = (habitsCompleted / dayHabits.length) * 30;
      }
      double journalComponent = 0;
      if (journal != null) {
        journalComponent = (journal.ratingSum / 15) * 20;
      }

      stats.add(DailyStat(
        day: d,
        score: (taskComponent + habitComponent + journalComponent).clamp(0, 100),
        tasksCompleted: dayTasks.where((t) => t.isCompleted).length,
        tasksTotal: dayTasks.length,
        habitsCompleted: habitsCompleted,
        habitsTotal: dayHabits.length,
        journalRatingSum: journal?.ratingSum ?? 0,
      ));
    }
    return stats;
  }

  /// Convenience: last 7 days including today.
  Future<List<DailyStat>> getWeeklyStats() {
    final now = DateTime.now();
    return getDailyStats(
      from: now.subtract(const Duration(days: 6)),
      to: now,
    );
  }

  /// Convenience: last 30 days including today.
  Future<List<DailyStat>> getMonthlyStats() {
    final now = DateTime.now();
    return getDailyStats(
      from: now.subtract(const Duration(days: 29)),
      to: now,
    );
  }
}
