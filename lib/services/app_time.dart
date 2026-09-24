const appTimeZoneOffset = Duration(hours: 8);

class AppTime {
  static DateTime now() {
    final utc = DateTime.now().toUtc().add(appTimeZoneOffset);
    return DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
  }

  static DateTime parse(String value) {
    final parsed = DateTime.parse(value);
    if (_hasTimeZone(value)) {
      final cst = parsed.toUtc().add(appTimeZoneOffset);
      return DateTime.utc(
        cst.year,
        cst.month,
        cst.day,
        cst.hour,
        cst.minute,
        cst.second,
        cst.millisecond,
        cst.microsecond,
      );
    }

    // Database records without an offset already contain +08:00 wall time.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static String serializeBusinessDate(DateTime date) {
    final utc = DateTime.utc(
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    ).subtract(appTimeZoneOffset);
    return utc.toIso8601String();
  }

  static bool _hasTimeZone(String value) {
    return value.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(value);
  }
}