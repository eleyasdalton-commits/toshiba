import '../models/task.dart';
import '../models/habit.dart';
import '../models/journal_entry.dart';

class ScoreService {
  /// Daily Score (%) =
  ///   (Completed Tasks / Total Tasks * 50)
  /// + (Habits Done / Total Habits * 30)
  /// + (Segment Ratings Sum / 15 * 20)
  ///
  /// Mirrors section 5 of the SRS exactly. Any component whose denominator
  /// is zero (e.g. no tasks logged yet) is skipped rather than divided by
  /// zero, so an empty day scores 0 instead of throwing.
  static double dailyScore({
    required List<AppTask> tasks,
    required List<Habit> habits,
    required JournalEntry? journal,
  }) {
    double taskComponent = 0;
    if (tasks.isNotEmpty) {
      final completed = tasks.where((t) => t.isCompleted).length;
      taskComponent = (completed / tasks.length) * 50;
    }

    double habitComponent = 0;
    if (habits.isNotEmpty) {
      final done = habits.where((h) => h.completedToday).length;
      habitComponent = (done / habits.length) * 30;
    }

    double journalComponent = 0;
    if (journal != null) {
      journalComponent = (journal.ratingSum / 15) * 20;
    }

    final total = taskComponent + habitComponent + journalComponent;
    return total.clamp(0, 100);
  }
}
