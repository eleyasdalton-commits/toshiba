package com.example.task_habit_tracker

// NOTE: adjust the `package` line above (and this file's folder) to match
// your actual applicationId if it differs from com.example.task_habit_tracker.

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Renders the small home-screen widget: today's score %, tasks done, and
/// habits done. Data is written by `HomeWidgetService` (lib/services/) via
/// `HomeWidget.saveWidgetData`, and this provider just reads it back out of
/// the shared prefs `home_widget` gives us — no Flutter engine required to
/// draw the widget, so it also survives the app being killed.
class TaskHabitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.task_habit_widget).apply {
                val score = widgetData.getFloat("widget_score", -1f)
                val scoreText = if (score >= 0) "${score.toInt()}%" else "--"
                val tasks = widgetData.getString("widget_tasks", "0/0")
                val habits = widgetData.getString("widget_habits", "0/0")

                setTextViewText(R.id.widget_score, scoreText)
                setTextViewText(R.id.widget_tasks, "ተግባራት: $tasks")
                setTextViewText(R.id.widget_habits, "ልምዶች: $habits")

                // Tapping the widget opens the app at the dashboard.
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
