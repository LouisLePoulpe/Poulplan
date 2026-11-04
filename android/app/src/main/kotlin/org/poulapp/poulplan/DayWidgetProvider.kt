package org.poulapp.poulplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/** « Journée »: every event of today, finished ones dimmed. */
class DayWidgetProvider : HomeWidgetProvider() {

    private val rows = listOf(
        listOf(R.id.day_row_0, R.id.day_row_0_time, R.id.day_row_0_bar, R.id.day_row_0_title, R.id.day_row_0_place),
        listOf(R.id.day_row_1, R.id.day_row_1_time, R.id.day_row_1_bar, R.id.day_row_1_title, R.id.day_row_1_place),
        listOf(R.id.day_row_2, R.id.day_row_2_time, R.id.day_row_2_bar, R.id.day_row_2_title, R.id.day_row_2_place),
        listOf(R.id.day_row_3, R.id.day_row_3_time, R.id.day_row_3_bar, R.id.day_row_3_title, R.id.day_row_3_place),
        listOf(R.id.day_row_4, R.id.day_row_4_time, R.id.day_row_4_bar, R.id.day_row_4_title, R.id.day_row_4_place),
        listOf(R.id.day_row_5, R.id.day_row_5_time, R.id.day_row_5_bar, R.id.day_row_5_title, R.id.day_row_5_place),
        listOf(R.id.day_row_6, R.id.day_row_6_time, R.id.day_row_6_bar, R.id.day_row_6_title, R.id.day_row_6_place),
        listOf(R.id.day_row_7, R.id.day_row_7_time, R.id.day_row_7_bar, R.id.day_row_7_title, R.id.day_row_7_place),
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
        val entries = WidgetSnapshot.read(widgetData)?.agenda?.get(today).orEmpty()
        val date = today.format(DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.FRENCH))
            .replaceFirstChar { it.titlecase(Locale.FRENCH) }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_day)
            views.setTextViewText(R.id.day_date, date)
            views.setOnClickPendingIntent(R.id.day_header, launchIntent(context, "open"))
            views.setOnClickPendingIntent(R.id.widget_add, launchIntent(context, "new"))
            views.setViewVisibility(
                R.id.day_empty, if (entries.isEmpty()) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.day_more,
                if (entries.size > rows.size) View.VISIBLE else View.GONE,
            )
            views.setTextViewText(R.id.day_more, "+ ${entries.size - rows.size}")
            rows.forEachIndexed { i, (row, time, bar, title, place) ->
                val entry = entries.getOrNull(i)
                if (entry == null) {
                    views.setViewVisibility(row, View.GONE)
                    return@forEachIndexed
                }
                val finished = !entry.allDay && entry.end <= now.toEpochMilli()
                views.setViewVisibility(row, View.VISIBLE)
                views.setTextViewText(
                    time,
                    if (entry.allDay) "Journée" else "${entry.time}\n${entry.endTime ?: ""}",
                )
                views.setTextViewText(title, entry.title)
                val location = entry.location?.takeIf { it.isNotBlank() }
                views.setViewVisibility(place, if (location == null) View.GONE else View.VISIBLE)
                views.setTextViewText(place, location ?: "")
                views.setInt(bar, "setBackgroundColor", entry.color)
                // Finished events are dimmed.
                val alpha = if (finished) 0x66 else 0xFF
                views.setTextColor(title, (alpha shl 24) or 0xFFF6C2)
                views.setTextColor(time, (alpha shl 24) or 0xFFF6C2)
                val target = if (entry.openable) "event/${Uri.encode(entry.id)}" else "open"
                views.setOnClickPendingIntent(row, launchIntent(context, target))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
