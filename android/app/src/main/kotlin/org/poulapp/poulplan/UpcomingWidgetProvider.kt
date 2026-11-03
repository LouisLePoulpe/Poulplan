package org.poulapp.poulplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** « À venir »: the next events; tapping one opens it in the app. */
class UpcomingWidgetProvider : HomeWidgetProvider() {

    private val rows = listOf(
        Triple(R.id.row_0, R.id.row_0_title, R.id.row_0_when),
        Triple(R.id.row_1, R.id.row_1_title, R.id.row_1_when),
        Triple(R.id.row_2, R.id.row_2_title, R.id.row_2_when),
        Triple(R.id.row_3, R.id.row_3_title, R.id.row_3_when),
        Triple(R.id.row_4, R.id.row_4_title, R.id.row_4_when),
        Triple(R.id.row_5, R.id.row_5_title, R.id.row_5_when),
    )
    private val bars = listOf(
        R.id.row_0_bar, R.id.row_1_bar, R.id.row_2_bar,
        R.id.row_3_bar, R.id.row_4_bar, R.id.row_5_bar,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val today = now.atZone(zone).toLocalDate()
        val entries = WidgetSnapshot.read(widgetData)?.upcomingAt(now, zone).orEmpty()

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming)
            val openApp = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("poulplan://open"),
            )
            views.setOnClickPendingIntent(R.id.widget_header, openApp)
            views.setViewVisibility(
                R.id.widget_empty, if (entries.isEmpty()) View.VISIBLE else View.GONE,
            )
            rows.forEachIndexed { i, (row, title, whenView) ->
                val entry = entries.getOrNull(i)
                if (entry == null) {
                    views.setViewVisibility(row, View.GONE)
                    return@forEachIndexed
                }
                views.setViewVisibility(row, View.VISIBLE)
                views.setTextViewText(title, entry.title)
                val day = dayLabel(entry.localDay, today)
                val time = entry.time?.let { " · $it" } ?: ""
                val place = entry.location?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""
                views.setTextViewText(whenView, "$day$time$place")
                views.setInt(bars[i], "setBackgroundColor", entry.color)
                val uri = if (entry.openable) {
                    Uri.parse("poulplan://event/${Uri.encode(entry.id)}")
                } else {
                    Uri.parse("poulplan://open")
                }
                views.setOnClickPendingIntent(
                    row,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
