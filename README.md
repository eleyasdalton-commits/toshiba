# Personal Task & Habit Tracker — Flutter

An offline-first Android task/habit tracker with AI-powered daily coaching.

## What's implemented

| SRS Section | Code |
|---|---|
| 1. To-Do, Habit, Challenge, Journal, Alarms | `lib/models/*`, `lib/screens/*` |
| 2. AI Engine (online Gemini / offline heuristic) | `lib/services/ai_service.dart` |
| 3. Dashboard UI/UX | `lib/screens/dashboard_screen.dart`, `lib/theme/app_theme.dart` |
| 4. Tech stack | Flutter, sqflite, flutter_local_notifications, provider, fl_chart, home_widget |
| 5. Daily score formula & 8:00 AM empty-list trigger | `lib/services/score_service.dart`, `lib/services/notification_service.dart` |
| Weekly/monthly performance charts | `lib/services/analytics_service.dart`, `lib/screens/stats_screen.dart` |
| Edit / delete flows | `lib/providers/app_provider.dart` (`updateTask`/`deleteTask`, `updateHabit`/`deleteHabit`/`undoHabitToday`, `updateChallenge`/`deleteChallenge`/`undoChallengeDay`), swipe-to-delete + tap-to-edit in each screen |
| Home-screen widget (Android) | `lib/services/home_widget_service.dart` + `android/app/src/main/kotlin/.../TaskHabitWidgetProvider.kt` |
| Dark/Light toggle UI | `lib/providers/theme_provider.dart`, toggle icon in the dashboard AppBar |
| Journal history / editing past entries | `lib/screens/journal_history_screen.dart`, `AppProvider.saveJournalForDate` / `getJournalHistory` |

Storage is local SQLite via `sqflite` — nothing needs a server to function.
The AI service checks connectivity and calls Gemini when online; when offline
(or if the API key isn't set) it falls back to a rule-based heuristic that
reads the same task/habit/journal data, so daily coaching always works.

## What's new in this pass

- **Habit completion history.** A new `habit_completions` table (SQLite
  migration v1 → v2, handled automatically for existing installs) records
  every day a habit was completed. Streaks are now *recomputed from this
  history* (`Habit.computeStreaksFromHistory`) instead of incremented by a
  fragile counter, so undo/edit can never desync a streak from reality.
- **Weekly/monthly charts.** `AnalyticsService.getWeeklyStats()` /
  `getMonthlyStats()` replay the same 50/30/20 score formula day-by-day over
  the last 7 or 30 days, and `StatsScreen` plots it with `fl_chart`
  (reachable from a new card on the dashboard). Only habits that existed by
  a given day count toward that day's score, so charts aren't skewed by
  habits you added last week.
- **Edit/delete everywhere.** Tasks, habits, and challenges all support:
  tap a row to open a pre-filled edit sheet (with a delete icon in the
  sheet's header), and swipe left to delete with a confirmation dialog.
  Habits also get an "undo today" tap on the checkmark, and challenges get
  an "undo last day" button next to "mark today."
- **Dark/Light toggle.** `ThemeProvider` persists the choice (`system` /
  `light` / `dark`) via `shared_preferences`; the icon button in the
  dashboard's AppBar cycles through the three and updates `MaterialApp`
  live.
- **Home-screen widget (Android).** `HomeWidgetService` pushes today's
  score/tasks/habits summary via the `home_widget` package every time
  `AppProvider.loadToday()` runs. The native side
  (`TaskHabitWidgetProvider.kt` + `res/layout/task_habit_widget.xml` +
  `res/xml/task_habit_widget_info.xml`) renders it without needing the
  Flutter engine running, and tapping the widget opens the app.

  **Package name note:** the native widget files assume the default Flutter
  package `com.example.task_habit_tracker`. If your project's real
  `applicationId` differs, rename the `kotlin/com/example/task_habit_tracker`
  folder to match and update the `package` line in both `.kt` files (and if
  you already have a `MainActivity.kt`, keep yours — the one here is just a
  plain `FlutterActivity` stub so the widget has something to launch).
  iOS home-screen widgets need a separate WidgetKit extension (Swift, in
  Xcode) and aren't included here, since the SRS's widget requirement was
  Android-focused.
- **Journal history.** `JournalScreen` now takes an optional `date` and a
  history icon in its AppBar opens `JournalHistoryScreen`, which lists every
  past day that has an entry (last 60 days) — tap one to view or correct it.
  `AppProvider.saveJournalForDate` reuses the existing entry's id for that
  day instead of creating a duplicate, so editing is a true update.

## Setup

1. Install the Flutter SDK (stable channel) and Android Studio / SDK.
2. From the project root:
   ```bash
   flutter pub get
   ```
3. (Optional, for online AI coaching) get a free Gemini API key from
   Google AI Studio, then run with:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_key_here
   ```
   Without a key, the app works fully offline using the rule-based coach.
4. Run on a device or emulator:
   ```bash
   flutter run
   ```
5. To try the home-screen widget: build and install the app once, then
   long-press your home screen → Widgets → "Task & Habit Tracker" → drag it
   onto the home screen. It refreshes automatically whenever you open the
   app and reload the dashboard (Android also force-refreshes it roughly
   every 30 minutes in the background, per `updatePeriodMillis`).

## Not yet built (suggested next steps)

- Custom alarm sound picker UI (currently accepts a raw resource name).
- iOS home-screen widget (WidgetKit) — Android-only for now.
- Interactive widget actions (e.g. checking off a task straight from the
  widget) — currently the widget is read-only and opens the app on tap.

## Pushing to GitHub

The repo is ready to push as-is:

```bash
cd task_habit_tracker
git init
git add .
git commit -m "Task & Habit Tracker: charts, edit/delete, theme toggle, home widget, journal history"
git branch -M main
git remote add origin <your-empty-repo-url>
git push -u origin main
```

`.gitignore` already excludes `.dart_tool/`, `build/`, `pubspec.lock`,
Android/iOS build artifacts, and anything named `*.env` (so a local
`--dart-define` file with your Gemini key never gets committed by accident —
pass the key on the command line instead, as shown above).

`analysis_options.yaml` is included so `flutter analyze` and your IDE pick up
the standard `flutter_lints` rule set immediately after `flutter pub get`.

## Notes on this sandbox

This code was written directly to files — it hasn't been compiled here,
since this environment doesn't have the Flutter/Android SDKs or access to
pub.dev. Run `flutter pub get` and `flutter run` locally to build it. The
`android/` folder here only contains the files this pass touched (manifest,
widget provider/layout, a stub `MainActivity.kt`) — merge them into your
full `flutter create`-generated Android project rather than replacing it
wholesale.
