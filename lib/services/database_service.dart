import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';
import '../models/habit.dart';
import '../models/challenge.dart';
import '../models/journal_entry.dart';

/// Single offline-first SQLite store for the whole app. Every screen reads
/// and writes through here — there is no server dependency for core
/// functionality, matching the SRS's offline-first requirement.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'task_habit_tracker.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT,
            priority TEXT NOT NULL,
            scope TEXT NOT NULL,
            dueAt TEXT NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            completedAt TEXT,
            alarmAt TEXT,
            alarmSound TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE habits(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT,
            currentStreak INTEGER NOT NULL DEFAULT 0,
            bestStreak INTEGER NOT NULL DEFAULT 0,
            lastCompletedAt TEXT,
            alarmAt TEXT,
            completedToday INTEGER NOT NULL DEFAULT 0,
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE challenges(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            startDate TEXT NOT NULL,
            totalDays INTEGER NOT NULL,
            completedDays INTEGER NOT NULL DEFAULT 0,
            alarmAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE journal_entries(
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            morningRating INTEGER NOT NULL DEFAULT 0,
            afternoonRating INTEGER NOT NULL DEFAULT 0,
            eveningRating INTEGER NOT NULL DEFAULT 0,
            reflection TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE habit_completions(
            id TEXT PRIMARY KEY,
            habitId TEXT NOT NULL,
            date TEXT NOT NULL,
            UNIQUE(habitId, date)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 → v2: per-day habit completion history (powers weekly/monthly
          // charts and lets undo/edit recompute streaks correctly instead of
          // just incrementing/decrementing a counter).
          await db.execute('''
            CREATE TABLE IF NOT EXISTS habit_completions(
              id TEXT PRIMARY KEY,
              habitId TEXT NOT NULL,
              date TEXT NOT NULL,
              UNIQUE(habitId, date)
            )
          ''');
          await db.execute(
              'ALTER TABLE habits ADD COLUMN createdAt TEXT');
          // Backfill createdAt for existing rows and seed today's history
          // row for any habit already marked completedToday, so nothing
          // "loses" its streak on upgrade.
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final habitRows = await db.query('habits');
          for (final row in habitRows) {
            await db.update(
              'habits',
              {'createdAt': today.toIso8601String()},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            if ((row['completedToday'] as int? ?? 0) == 1) {
              await db.insert(
                'habit_completions',
                {
                  'id': '${row['id']}_${today.toIso8601String()}',
                  'habitId': row['id'],
                  'date': today.toIso8601String(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      },
    );
  }

  // ---------------- Tasks ----------------
  Future<void> upsertTask(AppTask task) async {
    final db = await database;
    await db.insert('tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AppTask>> getTasksForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.query(
      'tasks',
      where: 'dueAt >= ? AND dueAt < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'priority ASC, dueAt ASC',
    );
    return rows.map(AppTask.fromMap).toList();
  }

  Future<bool> hasAnyTaskToday() async {
    final tasks = await getTasksForDay(DateTime.now());
    return tasks.isNotEmpty;
  }

  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// All tasks with a `dueAt` inside [from, to) (inclusive start, exclusive
  /// end), used by [AnalyticsService] to build the weekly/monthly charts.
  Future<List<AppTask>> getTasksInRange(DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'tasks',
      where: 'dueAt >= ? AND dueAt < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'dueAt ASC',
    );
    return rows.map(AppTask.fromMap).toList();
  }

  // ---------------- Habits ----------------
  Future<void> upsertHabit(Habit habit) async {
    final db = await database;
    await db.insert('habits', habit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Habit>> getAllHabits() async {
    final db = await database;
    final rows = await db.query('habits', orderBy: 'name ASC');
    return rows.map(Habit.fromMap).toList();
  }

  Future<void> deleteHabit(String id) async {
    final db = await database;
    await db.delete('habits', where: 'id = ?', whereArgs: [id]);
    await db.delete('habit_completions', where: 'habitId = ?', whereArgs: [id]);
  }

  // ---------------- Habit completions (history) ----------------

  /// Marks [habitId] as completed on the given [day] (time truncated).
  /// Idempotent — completing the same day twice is a no-op thanks to the
  /// UNIQUE(habitId, date) constraint.
  Future<void> addHabitCompletion(String habitId, DateTime day) async {
    final db = await database;
    final d = DateTime(day.year, day.month, day.day);
    await db.insert(
      'habit_completions',
      {
        'id': '${habitId}_${d.toIso8601String()}',
        'habitId': habitId,
        'date': d.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Removes the completion record for [habitId] on [day] — used by the
  /// "undo today" action.
  Future<void> removeHabitCompletion(String habitId, DateTime day) async {
    final db = await database;
    final d = DateTime(day.year, day.month, day.day);
    await db.delete(
      'habit_completions',
      where: 'habitId = ? AND date = ?',
      whereArgs: [habitId, d.toIso8601String()],
    );
  }

  /// Full completion history for one habit, sorted oldest → newest. Used to
  /// recompute streaks from scratch so they never drift.
  Future<List<DateTime>> getHabitCompletionDates(String habitId) async {
    final db = await database;
    final rows = await db.query(
      'habit_completions',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'date ASC',
    );
    return rows.map((r) => DateTime.parse(r['date'] as String)).toList();
  }

  /// habitId → list of completion dates within [from, to], for every habit
  /// at once. Used by [AnalyticsService] to build the chart without one
  /// query per habit per day.
  Future<Map<String, List<DateTime>>> getHabitCompletionsInRange(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'habit_completions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
    );
    final map = <String, List<DateTime>>{};
    for (final r in rows) {
      final habitId = r['habitId'] as String;
      map.putIfAbsent(habitId, () => []).add(DateTime.parse(r['date'] as String));
    }
    return map;
  }

  // ---------------- Challenges ----------------
  Future<void> upsertChallenge(Challenge challenge) async {
    final db = await database;
    await db.insert('challenges', challenge.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Challenge>> getActiveChallenges() async {
    final db = await database;
    final rows = await db.query('challenges', orderBy: 'startDate DESC');
    return rows.map(Challenge.fromMap).where((c) => !c.isFinished).toList();
  }

  Future<void> deleteChallenge(String id) async {
    final db = await database;
    await db.delete('challenges', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- Journal ----------------
  Future<void> upsertJournalEntry(JournalEntry entry) async {
    final db = await database;
    await db.insert('journal_entries', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<JournalEntry?> getJournalEntryForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day);
    final rows = await db.query(
      'journal_entries',
      where: 'date = ?',
      whereArgs: [start.toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<List<JournalEntry>> getJournalEntriesInRange(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.query(
      'journal_entries',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date ASC',
    );
    return rows.map(JournalEntry.fromMap).toList();
  }
}
