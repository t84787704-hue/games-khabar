package com.gameskhabar.games_khabar

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.util.concurrent.TimeUnit

class CountdownWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Flutter SharedPreferences keys are prefixed with "flutter."
            val gameName = prefs.getString("flutter.widget_game_name", null)
                ?: prefs.getString("widget_game_name", "Grand Theft Auto VI")
                ?: "Grand Theft Auto VI"

            // Target release epoch (seconds)
            var releaseEpochSec = prefs.getLong("flutter.widget_release_epoch_seconds", 0L)
            if (releaseEpochSec == 0L) {
                releaseEpochSec = prefs.getInt("flutter.widget_release_epoch_seconds", 0).toLong()
            }
            if (releaseEpochSec == 0L) {
                // Default fallback: Oct 15, 2025
                releaseEpochSec = 1760486400L
            }

            val currentEpochSec = System.currentTimeMillis() / 1000L
            val diffSec = releaseEpochSec - currentEpochSec

            val countdownStr = if (diffSec <= 0) {
                "🚀 AVAILABLE NOW!"
            } else {
                val days = TimeUnit.SECONDS.toDays(diffSec)
                val hours = TimeUnit.SECONDS.toHours(diffSec) % 24
                val minutes = TimeUnit.SECONDS.toMinutes(diffSec) % 60
                "${days}D ${hours}H ${minutes}M REMAINING"
            }

            val views = RemoteViews(context.packageName, R.layout.countdown_widget)
            views.setTextViewText(R.id.widget_game_title, gameName)
            views.setTextViewText(R.id.widget_countdown_text, countdownStr)

            // Tap widget to launch app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
