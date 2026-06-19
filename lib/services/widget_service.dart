import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_provider.dart';

class WidgetService {
  /// Extract statistics, format them, write to native widget shared storage, and update widget UI.
  static Future<void> updateWidgets(AppProvider provider) async {
    final profile = provider.activeProfile;
    if (profile == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isSunday = today.weekday == DateTime.sunday;
    final isHoliday = provider.isHolidayDate(today);
    final isManuallyMarked = provider.isManuallyMarked(today);

    String todayStatus;
    if (isManuallyMarked) {
      todayStatus = provider.statusFor(today)?.name ?? 'pending';
    } else if (isSunday) {
      todayStatus = 'sunday';
    } else if (isHoliday) {
      todayStatus = 'holiday';
    } else {
      todayStatus = provider.statusFor(today)?.name ?? 'pending';
    }

    // Manage marked time persistence
    final prefs = await SharedPreferences.getInstance();
    final timeKey = 'widget_marked_time_${profile.id}_${DateFormat('yyyy-MM-dd').format(now)}';
    String todayTime;

    final isMarked = todayStatus != 'pending' && todayStatus != 'sunday' && todayStatus != 'holiday';
    if (isMarked) {
      String? savedTime = prefs.getString(timeKey);
      if (savedTime == null) {
        savedTime = DateFormat('hh:mm a').format(now);
        await prefs.setString(timeKey, savedTime);
      }
      todayTime = savedTime;
    } else {
      todayTime = 'Mark Today';
    }

    // Get statistics for the current month
    final stats = provider.stats(month: DateTime(now.year, now.month));

    // Format money
    final f = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final earnedStr = f.format(stats.earnedSalary).trim();
    final estimatedStr = f.format(profile.monthlySalary).trim();
    final salaryProgressPercent = profile.monthlySalary == 0
        ? 0
        : ((stats.earnedSalary / profile.monthlySalary) * 100).round().clamp(0, 100);

    final widgetDate = DateFormat('MMMM dd, yyyy').format(now);
    final monthYear = DateFormat('MMMM yyyy').format(now);

    // Save data to widget shared preferences
    final todayStatusDate = DateFormat('yyyy-MM-dd').format(now);
    await HomeWidget.saveWidgetData<String>('today_status', todayStatus);
    await HomeWidget.saveWidgetData<String>('today_status_date', todayStatusDate);
    await HomeWidget.saveWidgetData<String>('today_time', todayTime);
    await HomeWidget.saveWidgetData<String>('widget_date', widgetDate);
    await HomeWidget.saveWidgetData<String>('profile_name', profile.name);
    await HomeWidget.saveWidgetData<String>('month_year', monthYear);
    await HomeWidget.saveWidgetData<String>('present_count', stats.presentDays.toString());
    await HomeWidget.saveWidgetData<String>('half_day_count', stats.halfDays.toString());
    await HomeWidget.saveWidgetData<String>('absent_count', stats.absentDays.toString());
    await HomeWidget.saveWidgetData<String>('attendance_score', '${stats.percentage.toStringAsFixed(1)}%');
    await HomeWidget.saveWidgetData<String>('earned_salary', earnedStr);
    await HomeWidget.saveWidgetData<String>('estimated_salary', estimatedStr);
    await HomeWidget.saveWidgetData<int>('salary_progress', salaryProgressPercent);
    await HomeWidget.saveWidgetData<double>('monthly_salary', profile.monthlySalary);

    // Update each widget provider
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.attendancetracker.attend.WidgetProvider1x1');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.attendancetracker.attend.WidgetProvider2x1');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.attendancetracker.attend.WidgetProvider2x2');
    await HomeWidget.updateWidget(qualifiedAndroidName: 'com.attendancetracker.attend.WidgetProvider4x2');
  }
}
