import 'package:home_widget/home_widget.dart';

/// Pushes the day's summary to the native Android home-screen widget
/// (see android/.../TaskHabitWidgetProvider.kt + task_habit_widget.xml).
/// Uses `home_widget`'s shared key-value store, which the native
/// AppWidgetProvider reads directly — no Flutter engine needs to be
/// running for the widget to display stale-but-correct data.
class HomeWidgetService {
  HomeWidgetService._internal();
  static final HomeWidgetService instance = HomeWidgetService._internal();

  static const _androidWidgetName = 'TaskHabitWidgetProvider';

  Future<void> updateWidget({
    required double score,
    required int tasksCompleted,
    required int tasksTotal,
    required int habitsCompleted,
    required int habitsTotal,
  }) async {
    try {
      await HomeWidget.saveWidgetData<double>('widget_score', score);
      await HomeWidget.saveWidgetData<String>(
          'widget_tasks', '$tasksCompleted/$tasksTotal');
      await HomeWidget.saveWidgetData<String>(
          'widget_habits', '$habitsCompleted/$habitsTotal');
      await HomeWidget.saveWidgetData<String>(
          'widget_updated_at', DateTime.now().toIso8601String());
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: null,
      );
    } catch (_) {
      // Widget updates are best-effort — e.g. no widget pinned yet, or the
      // native side isn't wired up in this build. Never let this crash the
      // main app flow.
    }
  }
}
