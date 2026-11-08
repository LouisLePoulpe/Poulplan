package org.poulapp.poulplan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/** Current month with today highlighted and a dot per busy day. */
class MonthWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val snapshot = WidgetSnapshot.read(widgetData)
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id, snapshot)
        }
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

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        snapshot: WidgetSnapshot?,
    ) {
        val options = manager.getAppWidgetOptions(id)
        val density = context.resources.displayMetrics.density
        val widthDp = max(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250), 180)
        val heightDp = max(options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 250), 180)
        // Two bitmaps (light and dark theme, the layout shows the one of the
        // system theme) must fit together in the RemoteViews memory budget
        // (1.5 × the screen in ARGB_8888).
        val metrics = context.resources.displayMetrics
        val budgetPixels = metrics.widthPixels.toFloat() * metrics.heightPixels * 1.5f / 2.2f
        val scale = min(min(density, 2.5f), sqrt(budgetPixels / (widthDp * heightDp)))
        val width = (widthDp * scale).toInt()
        val height = (heightDp * scale).toInt()
        val views = RemoteViews(context.packageName, R.layout.widget_month)
        views.setImageViewBitmap(R.id.month_image, drawMonth(context, false, width, height, scale, snapshot))
        views.setImageViewBitmap(R.id.month_image_night, drawMonth(context, true, width, height, scale, snapshot))
        val open = HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("poulplan://open"),
        )
        views.setOnClickPendingIntent(R.id.month_image, open)
        views.setOnClickPendingIntent(R.id.month_image_night, open)
        manager.updateAppWidget(id, views)
    }

    private fun drawMonth(
        context: Context,
        night: Boolean,
        width: Int,
        height: Int,
        dp: Float,
        snapshot: WidgetSnapshot?,
    ): Bitmap {
        val textColor = context.themedColor(R.color.widget_text, night)
        val dimColor = context.themedColor(R.color.widget_text_dim, night)
        val accentColor = context.themedColor(R.color.widget_accent, night)
        val buttonText = context.themedColor(R.color.widget_button_text, night)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val background = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = context.themedColor(R.color.widget_background, night) }
        canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(), 16 * dp, 16 * dp, background)

        val today = LocalDate.now()
        val first = today.withDayOfMonth(1)
        val firstDayOfWeek = snapshot?.firstDayOfWeek ?: 1
        val offset = (first.dayOfWeek.value - firstDayOfWeek + 7) % 7
        val start = first.minusDays(offset.toLong())
        val weeks = (offset + first.lengthOfMonth() + 6) / 7

        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = textColor
            textAlign = Paint.Align.CENTER
        }
        val pad = 8 * dp
        val titleHeight = 28 * dp
        text.textSize = 16 * dp
        text.typeface = Typeface.DEFAULT_BOLD
        val title = today.format(DateTimeFormatter.ofPattern("LLLL yyyy", Locale.FRENCH))
            .replaceFirstChar { it.titlecase(Locale.FRENCH) }
        canvas.drawText(title, width / 2f, pad + 16 * dp, text)

        val headerHeight = 18 * dp
        val cellWidth = (width - 2 * pad) / 7f
        val cellHeight = (height - pad * 2 - titleHeight - headerHeight) / weeks
        text.typeface = Typeface.DEFAULT
        text.textSize = 11 * dp
        text.color = dimColor
        for (i in 0 until 7) {
            val weekday = java.time.DayOfWeek.of((firstDayOfWeek - 1 + i) % 7 + 1)
            val label = weekday.getDisplayName(TextStyle.NARROW, Locale.FRENCH).uppercase()
            canvas.drawText(label, pad + cellWidth * (i + 0.5f), pad + titleHeight + 12 * dp, text)
        }

        val todayPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accentColor }
        val dot = Paint(Paint.ANTI_ALIAS_FLAG)
        text.textSize = 13 * dp
        val top = pad + titleHeight + headerHeight
        for (week in 0 until weeks) {
            for (col in 0 until 7) {
                val day = start.plusDays((week * 7 + col).toLong())
                if (day.month != first.month) continue
                val cx = pad + cellWidth * (col + 0.5f)
                val cy = top + cellHeight * week + cellHeight * 0.42f
                val radius = min(cellWidth, cellHeight) * 0.36f
                if (day == today) {
                    canvas.drawCircle(cx, cy, radius, todayPaint)
                    text.color = buttonText
                    text.typeface = Typeface.DEFAULT_BOLD
                } else {
                    text.color = textColor
                    text.typeface = Typeface.DEFAULT
                }
                canvas.drawText("${day.dayOfMonth}", cx, cy + text.textSize * 0.35f, text)
                val colors = snapshot?.busyDays?.get(day).orEmpty()
                colors.forEachIndexed { i, color ->
                    dot.color = color or 0xFF000000.toInt()
                    val dx = (i - (colors.size - 1) / 2f) * 6 * dp
                    canvas.drawCircle(cx + dx, cy + radius + 4 * dp, 2.2f * dp, dot)
                }
            }
        }
        return bitmap
    }
}
