package org.poulapp.poulplan

import android.content.SharedPreferences
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt
import org.json.JSONObject

/** One upcoming event, as exported by the app (lib/domain/widgets). */
data class WidgetEntry(
    val id: String,
    val title: String,
    val end: Long,
    val allDay: Boolean,
    val localDay: LocalDate,
    val time: String?,
    val endTime: String?,
    val color: Int,
    val location: String?,
    val openable: Boolean,
)

/** Snapshot written by the app; the widgets re-read it on every update. */
class WidgetSnapshot(
    val firstDayOfWeek: Int,
    val upcoming: List<WidgetEntry>,
    val busyDays: Map<LocalDate, List<Int>>,
    /** All the events of each day of the coming week (« Journée » widget). */
    val agenda: Map<LocalDate, List<WidgetEntry>>,
) {
    /** Events not over yet at [now] (the snapshot may be a few hours old). */
    fun upcomingAt(now: Instant, zone: ZoneId): List<WidgetEntry> {
        val today = now.atZone(zone).toLocalDate()
        return upcoming.filter { e ->
            if (e.allDay) {
                // End is the UTC midnight of the (exclusive) end date.
                Instant.ofEpochMilli(e.end).atZone(ZoneOffset.UTC).toLocalDate().isAfter(today)
            } else {
                e.end > now.toEpochMilli()
            }
        }
    }

    companion object {
        const val KEY = "snapshot"

        fun read(prefs: SharedPreferences): WidgetSnapshot? {
            val raw = prefs.getString(KEY, null) ?: return null
            return try {
                parse(JSONObject(raw))
            } catch (e: Exception) {
                null
            }
        }

        private fun entry(o: JSONObject) = WidgetEntry(
            id = o.getString("id"),
            title = o.getString("title"),
            end = o.getLong("end"),
            allDay = o.getBoolean("allDay"),
            localDay = LocalDate.parse(o.getString("localDay")),
            time = if (o.isNull("time")) null else o.getString("time"),
            endTime = if (o.isNull("endTime")) null else o.optString("endTime"),
            color = o.getLong("color").toInt(),
            location = if (o.isNull("location")) null else o.getString("location"),
            openable = o.optBoolean("openable", true),
        )

        private fun parse(json: JSONObject): WidgetSnapshot {
            val list = json.getJSONArray("upcoming")
            val entries = (0 until list.length()).map { entry(list.getJSONObject(it)) }
            val busy = json.getJSONObject("busyDays")
            val days = mutableMapOf<LocalDate, List<Int>>()
            for (key in busy.keys()) {
                val colors = busy.getJSONArray(key)
                days[LocalDate.parse(key)] = (0 until colors.length()).map {
                    colors.getLong(it).toInt()
                }
            }
            val agendaJson = json.optJSONObject("agenda") ?: JSONObject()
            val agenda = mutableMapOf<LocalDate, List<WidgetEntry>>()
            for (key in agendaJson.keys()) {
                val items = agendaJson.getJSONArray(key)
                agenda[LocalDate.parse(key)] =
                    (0 until items.length()).map { entry(items.getJSONObject(it)) }
            }
            return WidgetSnapshot(json.optInt("firstDayOfWeek", 1), entries, days, agenda)
        }
    }
}

/** Opens the app on a given screen ([path]: open, new, event/<id>). */
fun launchIntent(context: android.content.Context, path: String): android.app.PendingIntent =
    es.antonborri.home_widget.HomeWidgetLaunchIntent.getActivity(
        context, MainActivity::class.java, android.net.Uri.parse("poulplan://$path"),
    )

/** « Aujourd'hui », « Demain » or « mar. 5 nov. ». */
fun dayLabel(day: LocalDate, today: LocalDate): String = when (day) {
    today -> "Aujourd'hui"
    today.plusDays(1) -> "Demain"
    else -> day.format(DateTimeFormatter.ofPattern("EEE d MMM", Locale.FRENCH))
        .replaceFirstChar { it.titlecase(Locale.FRENCH) }
}

/** Extra scroll Android adds when it scrolls an item into view (fading edge length). */
private const val FADING_EDGE_DP = 12f

/**
 * Adapter position to hand to `smoothScrollToPosition` so that the red line
 * (the current time) ends up in the middle of the time line.
 *
 * Scrolling down to a position that is not visible yet brings that item to
 * the bottom of the list, [FADING_EDGE_DP] short of the edge (the list's
 * extra scroll). The line is then `(position + 1 - nowHours)` hours above
 * that bottom, so the position that puts it at half the height is
 * `nowHours - 1 + (listDp / 2 - edge) / hourDp`, rounded to the nearest hour
 * (precision: half an hour). Early in the morning the target is already on
 * screen and nothing scrolls; late in the evening the list stops at 23:00.
 */
fun centeredScrollTarget(nowMinute: Int, listDp: Float, hourDp: Float): Int {
    val nowHours = nowMinute / 60f
    val target = nowHours - 1f + (listDp / 2f - FADING_EDGE_DP) / hourDp
    return target.roundToInt().coerceIn(0, 23)
}

/** A colour resource resolved for the light or the dark theme, whatever the system's. */
fun android.content.Context.themedColor(id: Int, night: Boolean): Int {
    val config = android.content.res.Configuration(resources.configuration)
    val mode = if (night) {
        android.content.res.Configuration.UI_MODE_NIGHT_YES
    } else {
        android.content.res.Configuration.UI_MODE_NIGHT_NO
    }
    config.uiMode = (config.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK.inv()) or mode
    return createConfigurationContext(config).getColor(id)
}
