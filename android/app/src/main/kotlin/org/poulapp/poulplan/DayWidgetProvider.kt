package org.poulapp.poulplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/**
 * « Journée »: today as a time line (hours, events where they are, a line for
 * the current time) on Android 12+, a simple list on older versions.
 */
class DayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = WidgetSnapshot.read(widgetData)
        for (id in appWidgetIds) render(context, appWidgetManager, id, snapshot)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        render(context, appWidgetManager, appWidgetId, WidgetSnapshot.read(prefs))
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int, snapshot: WidgetSnapshot?) {
        val zone = ZoneId.systemDefault()
        val now = Instant.now()
        val today = now.atZone(zone).toLocalDate()
        val entries = snapshot?.agenda?.get(today).orEmpty()
        val date = today.format(DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.FRENCH))
            .replaceFirstChar { it.titlecase(Locale.FRENCH) }
        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            timeline(context, manager.getAppWidgetOptions(id), entries, now, zone)
        } else {
            DayListRenderer.render(context, entries, now)
        }
        views.setTextViewText(R.id.day_date, date)
        views.setOnClickPendingIntent(R.id.day_header, launchIntent(context, "open"))
        views.setOnClickPendingIntent(R.id.widget_add, launchIntent(context, "new"))
        manager.updateAppWidget(id, views)
    }

    private fun target(entry: WidgetEntry) =
        if (entry.openable) "event/${Uri.encode(entry.id)}" else "open"

    private fun minutes(time: String?): Int? = time?.let {
        val t = LocalTime.parse(it)
        t.hour * 60 + t.minute
    }

    private fun timeline(
        context: Context,
        options: Bundle,
        entries: List<WidgetEntry>,
        now: Instant,
        zone: ZoneId,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day)
        val density = context.resources.displayMetrics.density
        val nowMinute = now.atZone(zone).toLocalTime().let { it.hour * 60 + it.minute }

        // All-day events: up to two chips above the time line.
        val allDay = entries.filter { it.allDay }
        val allDayViews = listOf(R.id.tl_allday_0, R.id.tl_allday_1)
        views.setViewVisibility(R.id.tl_allday_row, if (allDay.isEmpty()) View.GONE else View.VISIBLE)
        allDayViews.forEachIndexed { i, viewId ->
            val entry = allDay.getOrNull(i)
            if (entry == null) {
                views.setViewVisibility(viewId, View.GONE)
                return@forEachIndexed
            }
            views.setViewVisibility(viewId, View.VISIBLE)
            val more = if (i == allDayViews.lastIndex && allDay.size > allDayViews.size) {
                " (+${allDay.size - allDayViews.size})"
            } else ""
            views.setTextViewText(viewId, entry.title + more)
            views.setInt(viewId, "setBackgroundColor", entry.color or 0xFF000000.toInt())
            views.setOnClickPendingIntent(viewId, launchIntent(context, target(entry)))
        }

        // Size of the time line, in dp.
        val widthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250) - 24f
        val heightDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250) -
            24f - 46f - (if (allDay.isEmpty()) 0f else 26f)
        val timed = entries.filter { !it.allDay }
            .map { e -> Triple(e, minutes(e.time) ?: 0, minutes(e.endTime) ?: (24 * 60)) }
            .map { (e, start, end) -> Triple(e, start, if (end <= start) 24 * 60 else end) }

        // Hours shown: around the events and now, as many as fit (≥ 20 dp/h).
        val maxHours = max(3, (heightDp / 20f).toInt())
        var first = min(8, nowMinute / 60)
        var last = max(20, nowMinute / 60 + 1)
        timed.forEach { (_, start, end) ->
            first = min(first, start / 60)
            last = max(last, (end + 59) / 60)
        }
        last = min(last, 24)
        if (last - first > maxHours) {
            // Keep the current hour in view, starting a little before it.
            first = max(0, min(nowMinute / 60 - 1, 24 - maxHours))
            last = first + maxHours
        }
        val hours = last - first
        val dpPerMinute = heightDp / (hours * 60f)
        val gutterDp = 38f

        views.setImageViewBitmap(
            R.id.day_grid,
            drawGrid(widthDp, heightDp, min(density, 2.5f), first, last, nowMinute, gutterDp),
        )

        // Event boxes, side by side when they overlap.
        val sorted = timed.sortedWith(compareBy({ it.second }, { -it.third }))
        val columnEnds = mutableListOf<Int>()
        val placed = sorted.map { (e, start, end) ->
            var col = columnEnds.indexOfFirst { it <= start }
            if (col == -1) {
                col = columnEnds.size
                columnEnds.add(end)
            } else {
                columnEnds[col] = end
            }
            Pair(Triple(e, start, end), col)
        }
        val columns = max(1, columnEnds.size)
        val eventViews = listOf(
            R.id.tl_event_0, R.id.tl_event_1, R.id.tl_event_2, R.id.tl_event_3,
            R.id.tl_event_4, R.id.tl_event_5, R.id.tl_event_6, R.id.tl_event_7,
        )
        val columnWidth = (widthDp - gutterDp) / columns
        eventViews.forEachIndexed { i, viewId ->
            val item = placed.getOrNull(i)
            val visible = item != null && item.first.third > first * 60 && item.first.second < last * 60
            if (!visible) {
                views.setViewVisibility(viewId, View.GONE)
                return@forEachIndexed
            }
            val (triple, col) = item!!
            val (entry, start, end) = triple
            val top = (max(start, first * 60) - first * 60) * dpPerMinute
            val bottom = (min(end, last * 60) - first * 60) * dpPerMinute
            val height = max(16f, bottom - top - 1f)
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setViewLayoutMargin(viewId, RemoteViews.MARGIN_TOP, top, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutMargin(
                viewId, RemoteViews.MARGIN_START, gutterDp + col * columnWidth, TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutWidth(viewId, columnWidth - 2f, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(viewId, height, TypedValue.COMPLEX_UNIT_DIP)
            val finished = entry.end <= now.toEpochMilli()
            val alpha = if (finished) 0x55 else 0xDD
            views.setInt(viewId, "setBackgroundColor", (alpha shl 24) or (entry.color and 0xFFFFFF))
            val time = if (height >= 30f) "\n${entry.time}–${entry.endTime ?: ""}" else ""
            views.setTextViewText(viewId, entry.title + time)
            views.setOnClickPendingIntent(viewId, launchIntent(context, target(entry)))
        }
        return views
    }

    /** Hour lines and labels, plus the red « now » line. */
    private fun drawGrid(
        widthDp: Float,
        heightDp: Float,
        dp: Float,
        first: Int,
        last: Int,
        nowMinute: Int,
        gutterDp: Float,
    ): Bitmap {
        val width = max(1, (widthDp * dp).toInt())
        val height = max(1, (heightDp * dp).toInt())
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val hourHeight = height.toFloat() / (last - first)
        val line = Paint().apply {
            color = 0x40FFF6C2
            strokeWidth = max(1f, dp * 0.6f)
        }
        val label = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0x99FFF6C2.toInt()
            textSize = 10 * dp
        }
        for (h in first..last) {
            val y = (h - first) * hourHeight
            canvas.drawLine(gutterDp * dp - 4 * dp, y, width.toFloat(), y, line)
            if (h < last) {
                canvas.drawText(String.format(Locale.FRENCH, "%02d:00", h % 24), 0f, y + 11 * dp, label)
            }
        }
        if (nowMinute >= first * 60 && nowMinute <= last * 60) {
            val y = (nowMinute - first * 60) / 60f * hourHeight
            val now = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = 0xFFE53935.toInt()
                strokeWidth = 2 * dp
            }
            canvas.drawCircle(gutterDp * dp - 3 * dp, y, 4 * dp, now)
            canvas.drawLine(gutterDp * dp - 3 * dp, y, width.toFloat(), y, now)
        }
        return bitmap
    }
}

/** List version of « Journée » for Android < 12 (no layout changes from code). */
object DayListRenderer {
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

    fun render(context: Context, entries: List<WidgetEntry>, now: Instant): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_list)
        views.setViewVisibility(R.id.day_empty, if (entries.isEmpty()) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.day_more, if (entries.size > rows.size) View.VISIBLE else View.GONE)
        views.setTextViewText(R.id.day_more, "+ ${entries.size - rows.size}")
        rows.forEachIndexed { i, (row, time, bar, title, place) ->
            val entry = entries.getOrNull(i)
            if (entry == null) {
                views.setViewVisibility(row, View.GONE)
                return@forEachIndexed
            }
            val finished = !entry.allDay && entry.end <= now.toEpochMilli()
            views.setViewVisibility(row, View.VISIBLE)
            views.setTextViewText(time, if (entry.allDay) "Journée" else "${entry.time}\n${entry.endTime ?: ""}")
            views.setTextViewText(title, entry.title)
            val location = entry.location?.takeIf { it.isNotBlank() }
            views.setViewVisibility(place, if (location == null) View.GONE else View.VISIBLE)
            views.setTextViewText(place, location ?: "")
            views.setInt(bar, "setBackgroundColor", entry.color)
            val alpha = if (finished) 0x66 else 0xFF
            views.setTextColor(title, (alpha shl 24) or 0xFFF6C2)
            views.setTextColor(time, (alpha shl 24) or 0xFFF6C2)
            val target = if (entry.openable) "event/${Uri.encode(entry.id)}" else "open"
            views.setOnClickPendingIntent(row, launchIntent(context, target))
        }
        return views
    }
}
