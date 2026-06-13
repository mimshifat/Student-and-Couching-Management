import 'package:intl/intl.dart';

class DateUtilsHelper {
  static final DateFormat _isoFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _isoDateTimeFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');

  // Format to store in DB
  static String formatForDb(DateTime date) {
    return _isoFormat.format(date);
  }

  // Parse from DB — accepts dynamic (String, int, or null) safely.
  // SQLite can return dates as TEXT, INTEGER (unix epoch), or NULL.
  static DateTime parseFromDb(dynamic raw) {
    if (raw == null) return DateTime.now();
    if (raw is int) {
      // Unix epoch in milliseconds (rare but possible)
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    final dateStr = raw.toString().trim();
    if (dateStr.isEmpty) return DateTime.now();
    try {
      if (dateStr.contains('T')) {
        return parseDateTimeFromDb(dateStr);
      }
      return _isoFormat.parse(dateStr);
    } catch (_) {
      // Last-resort: try Dart's built-in parser
      return DateTime.tryParse(dateStr) ?? DateTime.now();
    }
  }

  // Format to store in DB with Time
  static String formatDateTimeForDb(DateTime date) {
    return _isoDateTimeFormat.format(date.toUtc());
  }

  // Parse from DB with Time — also accepts dynamic
  static DateTime parseDateTimeFromDb(dynamic raw) {
    if (raw == null) return DateTime.now();
    final dateStr = raw.toString().trim();
    if (dateStr.isEmpty) return DateTime.now();
    try {
      return _isoDateTimeFormat.parse(dateStr, true).toLocal();
    } catch (_) {
      return DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();
    }
  }

  // Format for UI Display
  static String formatForDisplay(DateTime date) {
    return _displayFormat.format(date);
  }

  static String formatStringForDisplay(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      return _displayFormat.format(_isoFormat.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  // Format as Month Year (e.g., June 2025)
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }

  // Get start of next cycle based on admission date
  // For example, if admission date is 15th Jan, and current cycle ends 14th Feb,
  // next cycle is 15th Feb to 14th March.
  static DateTime getNextCycleStartDate(DateTime admissionDate, DateTime currentCycleStart) {
    int day = admissionDate.day;
    DateTime nextMonth = DateTime(currentCycleStart.year, currentCycleStart.month + 1, 1);
    
    // Handle months with fewer days than the admission day (e.g. Feb 30th -> Feb 28th)
    int lastDayOfNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    int targetDay = day > lastDayOfNextMonth ? lastDayOfNextMonth : day;
    
    return DateTime(nextMonth.year, nextMonth.month, targetDay);
  }

  // Get end date for a cycle starting on startDate
  static DateTime getCycleEndDate(DateTime startDate) {
    DateTime nextMonth = DateTime(startDate.year, startDate.month + 1, startDate.day);
    return nextMonth.subtract(const Duration(days: 1));
  }
}
