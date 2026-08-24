import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/task.dart';
import '../models/habit.dart';
import '../models/challenge.dart';
import '../models/journal_entry.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/score_service.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/home_widget_service.dart';

class AppProvider extends ChangeNotifier {
  final _db = DatabaseService.instance;
  final _notifications = NotificationService.instance;
  final _ai = AIService();
  final _uuid = const Uuid();
  final analytics = AnalyticsService();
  final _widget = HomeWidgetService.instance;

  List<AppTask> todayTasks = [];
  List<Habit> habits = [];
  List<Challenge> activeChallenges = [];
  JournalEntry? todayJournal;

  double dailyScore = 0;
  String aiFeedback = '';
  bool isLoading = true;

  Future<void> loadToday() async {
    isLoading = true;
    notifyListeners();

    todayTasks = await _db.getTasksForDay(DateTime.now());
    habits = await _db.getAllHabits();
    activeChallenges = await _db.getActiveChallenges();
    todayJournal = await _db.getJournalEntryForDay(DateTime.now());

    dailyScore = ScoreService.dailyScore(
      tasks: todayTasks,
      habits: habits,
      journal: todayJournal,
    );

    isLoading = false;
    notifyListeners();

    // Fetch AI feedback after the first paint so the dashboard isn't
    // blocked waiting on a network round trip.
    _refreshAiFeedback();

    // Best-effort push to the home-screen widget; never blocks the UI.
    _widget.updateWidget(
      score: dailyScore,
      tasksCompleted: todayTasks.where((t) => t.isCompleted).length,
      tasksTotal: todayTasks.length,
      habitsCompleted: habits.where((h) => h.completedToday).length,
      habitsTotal: habits.length,
    );
  }

  Future<void> _refreshAiFeedback() async {
    aiFeedback = await _ai.getDailyFeedback(
      tasks: todayTasks,
      habits: habits,
      journal: todayJournal,
    );
    notifyListeners();
  }

  // ---------------- Tasks ----------------
  Future<void> addTask({
    required String title,
    required String category,
    required TaskPriority priority,
    required TaskScope scope,
    required DateTime dueAt,
    DateTime? alarmAt,
    String? alarmSound,
  }) async {
    final task = AppTask(
      id: _uuid.v4(),
      title: title,
      category: category,
      priority: priority,
      scope: scope,
      dueAt: dueAt,
      alarmAt: alarmAt,
      alarmSound: alarmSound,
    );
    await _db.upsertTask(task);
    if (alarmAt != null) {
      await _notifications.scheduleAlarm(
        id: task.id.hashCode,
        title: 'ማሳሰቢያ',
        body: title,
        when: alarmAt,
        sound: alarmSound,
      );
    }
    await loadToday();
  }

  Future<void> toggleTaskCompleted(AppTask task) async {
    task.isCompleted = !task.isCompleted;
    task.completedAt = task.isCompleted ? DateTime.now() : null;
    await _db.upsertTask(task);
    await loadToday();
  }

  /// Full edit of an existing task (title/category/priority/scope/due/alarm).
  /// Re-arms the alarm if one is set, or cancels it if the user cleared it.
  Future<void> updateTask(AppTask task, {DateTime? newAlarmAt}) async {
    task.alarmAt = newAlarmAt;
    await _db.upsertTask(task);
    await _notifications.cancelAlarm(task.id.hashCode);
    if (newAlarmAt != null) {
      await _notifications.scheduleAlarm(
        id: task.id.hashCode,
        title: 'ማሳሰቢያ',
        body: task.title,
        when: newAlarmAt,
        sound: task.alarmSound,
      );
    }
    await loadToday();
  }

  Future<void> deleteTask(String id) async {
    await _notifications.cancelAlarm(id.hashCode);
    await _db.deleteTask(id);
    await loadToday();
  }

  // ---------------- Habits ----------------
  Future<void> addHabit(String name, {String? category, DateTime? alarmAt}) async {
    final habit = Habit(id: _uuid.v4(), name: name, category: category, alarmAt: alarmAt);
    await _db.upsertHabit(habit);
    if (alarmAt != null) {
      await _notifications.scheduleAlarm(
        id: habit.id.hashCode,
        title: 'የልምድ ማሳሰቢያ',
        body: name,
        when: alarmAt,
      );
    }
    await loadToday();
  }

  Future<void> completeHabitToday(Habit habit) async {
    await _db.addHabitCompletion(habit.id, DateTime.now());
    await _recomputeHabitStreak(habit);
    await loadToday();
  }

  /// Un-marks today's completion (e.g. the user tapped it by mistake) and
  /// recalculates the streak from the remaining history, rather than just
  /// decrementing a counter — so it stays correct even after gaps/edits.
  Future<void> undoHabitToday(Habit habit) async {
    await _db.removeHabitCompletion(habit.id, DateTime.now());
    await _recomputeHabitStreak(habit);
    await loadToday();
  }

  Future<void> _recomputeHabitStreak(Habit habit) async {
    final history = await _db.getHabitCompletionDates(habit.id);
    final result = Habit.computeStreaksFromHistory(history);
    habit.currentStreak = result.current;
    habit.bestStreak = result.best;
    habit.lastCompletedAt = result.last;
    habit.completedToday = result.today;
    await _db.upsertHabit(habit);
  }

  /// Edits name/category/alarm for an existing habit; streak fields are
  /// untouched here since they're derived from completion history.
  Future<void> updateHabit(Habit habit, {DateTime? newAlarmAt}) async {
    habit.alarmAt = newAlarmAt;
    await _db.upsertHabit(habit);
    await _notifications.cancelAlarm(habit.id.hashCode);
    if (newAlarmAt != null) {
      await _notifications.scheduleAlarm(
        id: habit.id.hashCode,
        title: 'የልምድ ማሳሰቢያ',
        body: habit.name,
        when: newAlarmAt,
      );
    }
    await loadToday();
  }

  Future<void> deleteHabit(String id) async {
    await _notifications.cancelAlarm(id.hashCode);
    await _db.deleteHabit(id);
    await loadToday();
  }

  // ---------------- Challenges ----------------
  Future<void> addChallenge(String title, int totalDays, {DateTime? alarmAt}) async {
    final challenge = Challenge(
      id: _uuid.v4(),
      title: title,
      startDate: DateTime.now(),
      totalDays: totalDays,
      alarmAt: alarmAt,
    );
    await _db.upsertChallenge(challenge);
    if (alarmAt != null) {
      await _notifications.scheduleAlarm(
        id: challenge.id.hashCode,
        title: 'ቻሌንጅ',
        body: title,
        when: alarmAt,
      );
    }
    await loadToday();
  }

  Future<void> logChallengeDay(Challenge challenge) async {
    if (challenge.completedDays < challenge.totalDays) {
      challenge.completedDays += 1;
      await _db.upsertChallenge(challenge);
      await loadToday();
    }
  }

  /// Undoes the most recent day-log, e.g. if the user tapped by mistake.
  Future<void> undoChallengeDay(Challenge challenge) async {
    if (challenge.completedDays > 0) {
      challenge.completedDays -= 1;
      await _db.upsertChallenge(challenge);
      await loadToday();
    }
  }

  /// Edits title/length/alarm for an existing challenge.
  Future<void> updateChallenge(Challenge challenge, {DateTime? newAlarmAt}) async {
    challenge.alarmAt = newAlarmAt;
    await _db.upsertChallenge(challenge);
    await _notifications.cancelAlarm(challenge.id.hashCode);
    if (newAlarmAt != null) {
      await _notifications.scheduleAlarm(
        id: challenge.id.hashCode,
        title: 'ቻሌንጅ',
        body: challenge.title,
        when: newAlarmAt,
      );
    }
    await loadToday();
  }

  Future<void> deleteChallenge(String id) async {
    await _notifications.cancelAlarm(id.hashCode);
    await _db.deleteChallenge(id);
    await loadToday();
  }

  // ---------------- Journal ----------------
  Future<void> saveJournal({
    required int morning,
    required int afternoon,
    required int evening,
    required String reflection,
  }) async {
    final entry = JournalEntry(
      id: todayJournal?.id ?? _uuid.v4(),
      date: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      morningRating: morning,
      afternoonRating: afternoon,
      eveningRating: evening,
      reflection: reflection,
    );
    await _db.upsertJournalEntry(entry);
    await loadToday();
  }

  /// Same as [saveJournal] but for an arbitrary past day, so users can fill
  /// in or correct an entry they missed. Reuses the existing entry's id if
  /// one exists for that day, so this is a true edit rather than a
  /// duplicate row.
  Future<void> saveJournalForDate({
    required DateTime date,
    required int morning,
    required int afternoon,
    required int evening,
    required String reflection,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final existing = await _db.getJournalEntryForDay(day);
    final entry = JournalEntry(
      id: existing?.id ?? _uuid.v4(),
      date: day,
      morningRating: morning,
      afternoonRating: afternoon,
      eveningRating: evening,
      reflection: reflection,
    );
    await _db.upsertJournalEntry(entry);
    await loadToday();
  }

  Future<JournalEntry?> getJournalForDate(DateTime date) =>
      _db.getJournalEntryForDay(date);

  /// Entries from the last [days] days (default 60), newest first — powers
  /// JournalHistoryScreen.
  Future<List<JournalEntry>> getJournalHistory({int days = 60}) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: days - 1));
    final entries = await _db.getJournalEntriesInRange(from, now);
    return entries.reversed.toList();
  }
}
