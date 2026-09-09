package com.attendancetracker.attend

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class WidgetProvider1x1 : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        AttendanceState.updateWidgetData(context)
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_1x1)
            WidgetHelper.updateViews1x1(context, views, widgetData)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
