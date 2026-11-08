package org.poulapp.poulplan

import android.app.ActivityOptions
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViews.RemoteCollectionItems
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.max
import kotlin.math.min

/**
 * « Journée »: today as a scrolling time line (24 hours, events where they
 * are, a line for the current time) on Android 12+, a list on older versions.
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
            val listDp = listHeightDp(context, manager, id, entries.any { it.allDay })
            timeline(context, entries, now, zone, listDp, nextViewTypeCount(context, id))
        } else {
            DayListRenderer.render(context, entries, now)
        }
        views.setTextViewText(R.id.day_date, date)
        views.setOnClickPendingIntent(R.id.day_header, launchIntent(context, "open"))
        views.setOnClickPendingIntent(R.id.widget_open, launchIntent(context, "open"))
        views.setOnClickPendingIntent(R.id.widget_add, launchIntent(context, "new"))
        manager.updateAppWidget(id, views)
    }

    /**
     * Estimated height of the time line in dp: the widget's height (portrait
     * or landscape size, as reported by the launcher) minus the padding, the
     * header and, when there are any, the all-day chips.
     */
    /**
     * 1, then 2, then 1… for each update of widget [id]. The launcher keeps
     * the list's adapter, and its scroll position, while the number of view
     * types stays the same: changing it gives a new adapter, so the list
     * starts again from the top and [centeredScrollTarget] (which scrolls
     * down from the top) always lands the « now » line in the middle,
     * wherever the list was before.
     */
    private fun nextViewTypeCount(context: Context, id: Int): Int {
        val prefs = context.getSharedPreferences("PoulplanDayWidget", Context.MODE_PRIVATE)
        val next = if (prefs.getInt("view_types_$id", 1) == 1) 2 else 1
        prefs.edit().putInt("view_types_$id", next).apply()
        return next
    }

    private fun listHeightDp(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        hasAllDay: Boolean,
    ): Float {
        val options = manager.getAppWidgetOptions(id)
        val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val key = if (landscape) {
            AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT
        } else {
            AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
        }
        val heightDp = options.getInt(key, 0).takeIf { it > 0 }?.toFloat() ?: DEFAULT_HEIGHT_DP
        return max(0f, heightDp - CHROME_DP - (if (hasAllDay) ALL_DAY_ROW_DP else 0f))
    }

    private fun target(entry: WidgetEntry) =
        if (entry.openable) "event/${Uri.encode(entry.id)}" else "open"

    private fun minutes(time: String?): Int? = time?.let {
        val t = LocalTime.parse(it)
        t.hour * 60 + t.minute
    }

    private fun timeline(
        context: Context,
        entries: List<WidgetEntry>,
        now: Instant,
        zone: ZoneId,
        listDp: Float,
        viewTypeCount: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day)
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

        val placed = layoutDay(entries.filter { !it.allDay })
        val hourDp = context.resources.getDimension(R.dimen.widget_hour_height) /
            context.resources.displayMetrics.density
        val items = RemoteCollectionItems.Builder().setHasStableIds(true)
            .setViewTypeCount(viewTypeCount)
        for (hour in 0 until 24) {
            items.addItem(hour.toLong(), hourItem(context, hour, hourDp, placed, now, nowMinute))
        }
        views.setRemoteAdapter(R.id.day_list, items.build())
        views.setPendingIntentTemplate(R.id.day_list, templateIntent(context))
        views.setScrollPosition(R.id.day_list, centeredScrollTarget(nowMinute, listDp, hourDp))
        return views
    }

    /** An event of the day, in minutes since midnight, and its column. */
    private class Placed(
        val entry: WidgetEntry,
        val start: Int,
        val end: Int,
        val column: Int,
        var columns: Int,
        var titleHour: Int = 0,
    )

    /**
     * Columns as in the calendar: overlapping events share the width of their
     * group, an event alone takes the whole width.
     */
    private fun layoutDay(timed: List<WidgetEntry>): List<Placed> {
        val sorted = timed.map { e ->
            val start = minutes(e.time) ?: 0
            var end = minutes(e.endTime) ?: (24 * 60)
            if (end <= start) end = 24 * 60
            Triple(e, start, max(end, min(start + 15, 24 * 60)))
        }.sortedWith(compareBy({ it.second }, { -it.third }))
        val placed = mutableListOf<Placed>()
        var group = mutableListOf<Placed>()
        val columnEnds = mutableListOf<Int>()
        var groupEnd = -1
        fun closeGroup() {
            val count = min(SLOTS, max(1, columnEnds.size))
            group.forEach { it.columns = count }
            group = mutableListOf()
            columnEnds.clear()
        }
        for ((e, start, end) in sorted) {
            if (start >= groupEnd) closeGroup()
            var col = columnEnds.indexOfFirst { it <= start }
            if (col == -1) {
                col = columnEnds.size
                columnEnds.add(end)
            } else {
                columnEnds[col] = end
            }
            val item = Placed(e, start, end, min(col, SLOTS - 1), 1)
            // Title in the hour that shows the biggest part of the event.
            item.titleHour = (start / 60..min(23, (end - 1) / 60)).maxByOrNull { h ->
                min(end, h * 60 + 60) - max(start, h * 60)
            } ?: (start / 60)
            group.add(item)
            placed.add(item)
            groupEnd = max(groupEnd, end)
        }
        closeGroup()
        return placed
    }

    private fun hourItem(
        context: Context,
        hour: Int,
        hourDp: Float,
        placed: List<Placed>,
        now: Instant,
        nowMinute: Int,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_hour)
        views.setTextViewText(R.id.tl_hour, String.format(Locale.FRENCH, "%02d:00", hour))
        val from = hour * 60
        val to = from + 60
        val dpPerMinute = hourDp / 60f
        val slices = placed.filter { it.start < to && it.end > from }.sortedBy { it.column }
        LANES.forEachIndexed { i, (lane, slots) ->
            val p = slices.getOrNull(i)
            if (p == null) {
                views.setViewVisibility(lane, View.GONE)
                return@forEachIndexed
            }
            // A small gap between two events that follow each other.
            val top = (max(p.start, from) - from) * dpPerMinute + (if (p.start >= from) 1f else 0f)
            val bottom = (min(p.end, to) - from) * dpPerMinute - (if (p.end <= to) 1f else 0f)
            views.setViewVisibility(lane, View.VISIBLE)
            views.setViewLayoutMargin(lane, RemoteViews.MARGIN_TOP, top, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(lane, max(1f, bottom - top), TypedValue.COMPLEX_UNIT_DIP)
            slots.forEachIndexed { c, slot ->
                when {
                    c >= p.columns -> views.setViewVisibility(slot, View.GONE)
                    c != p.column -> views.setViewVisibility(slot, View.INVISIBLE)
                    else -> {
                        views.setViewVisibility(slot, View.VISIBLE)
                        val finished = p.entry.end <= now.toEpochMilli()
                        val alpha = if (finished) 0x55 else 0xDD
                        views.setInt(slot, "setBackgroundColor", (alpha shl 24) or (p.entry.color and 0xFFFFFF))
                        if (finished) {
                            // Faded box: the text follows the system theme (Android 12+).
                            views.setColorInt(
                                slot, "setTextColor",
                                context.themedColor(R.color.widget_event_finished_text, night = false),
                                context.themedColor(R.color.widget_event_finished_text, night = true),
                            )
                        }
                        val text = if (hour == p.titleHour) {
                            val totalDp = (p.end - p.start) * dpPerMinute
                            val time = if (totalDp >= 34f) "\n${p.entry.time}–${p.entry.endTime ?: ""}" else ""
                            p.entry.title + time
                        } else ""
                        views.setTextViewText(slot, text)
                        views.setOnClickFillInIntent(
                            slot, Intent().setData(Uri.parse("poulplan://${target(p.entry)}")),
                        )
                    }
                }
            }
        }
        val showNow = nowMinute in from until to
        views.setViewVisibility(R.id.tl_now, if (showNow) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.tl_now_dot, if (showNow) View.VISIBLE else View.GONE)
        if (showNow) {
            val y = (nowMinute - from) * dpPerMinute
            views.setViewLayoutMargin(R.id.tl_now, RemoteViews.MARGIN_TOP, max(0f, y - 1f), TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutMargin(R.id.tl_now_dot, RemoteViews.MARGIN_TOP, max(0f, y - 4f), TypedValue.COMPLEX_UNIT_DIP)
        }
        return views
    }

    /** Opens the app; each event box fills in its poulplan:// link. */
    private fun templateIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return PendingIntent.getActivity(context, 1, intent, flags)
        }
        val options = ActivityOptions.makeBasic()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            options.setPendingIntentCreatorBackgroundActivityStartMode(
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED,
            )
        } else {
            @Suppress("DEPRECATION")
            options.pendingIntentBackgroundActivityStartMode =
                ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
        }
        return PendingIntent.getActivity(context, 1, intent, flags, options.toBundle())
    }

    private companion object {
        const val SLOTS = 4
        /** Used when the launcher does not report the widget's height. */
        const val DEFAULT_HEIGHT_DP = 250f
        /** Padding (2 × 12 dp) + header row (36 dp + 6 dp). */
        const val CHROME_DP = 24f + 42f
        /** All-day chips row (22 dp + 4 dp). */
        const val ALL_DAY_ROW_DP = 26f
        val LANES = listOf(
            R.id.tl_lane_0 to listOf(R.id.tl_lane_0_0, R.id.tl_lane_0_1, R.id.tl_lane_0_2, R.id.tl_lane_0_3),
            R.id.tl_lane_1 to listOf(R.id.tl_lane_1_0, R.id.tl_lane_1_1, R.id.tl_lane_1_2, R.id.tl_lane_1_3),
            R.id.tl_lane_2 to listOf(R.id.tl_lane_2_0, R.id.tl_lane_2_1, R.id.tl_lane_2_2, R.id.tl_lane_2_3),
            R.id.tl_lane_3 to listOf(R.id.tl_lane_3_0, R.id.tl_lane_3_1, R.id.tl_lane_3_2, R.id.tl_lane_3_3),
        )
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
            val textColor = (alpha shl 24) or (context.getColor(R.color.widget_text) and 0xFFFFFF)
            views.setTextColor(title, textColor)
            views.setTextColor(time, textColor)
            val target = if (entry.openable) "event/${Uri.encode(entry.id)}" else "open"
            views.setOnClickPendingIntent(row, launchIntent(context, target))
        }
        return views
    }
}
