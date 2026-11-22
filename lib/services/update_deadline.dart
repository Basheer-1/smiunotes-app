/// A date-only deadline is inclusive in Karachi (UTC+05:00).
/// As with the website, an absent deadline means no recorded expiry.
bool isUpdateApplicationExpired(Object? deadline, {DateTime? now}) {
  if (deadline is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$')
      .hasMatch(deadline)) { return false; }
  final instant = (now ?? DateTime.now()).toUtc()
      .add(const Duration(hours: 5));
  final localDate = '${instant.year.toString().padLeft(4, '0')}-'
      '${instant.month.toString().padLeft(2, '0')}-'
      '${instant.day.toString().padLeft(2, '0')}';
  return deadline.compareTo(localDate) < 0;
}

enum UniversityUpdateStatus { active, upcoming, expired }

/// Matches the public website's priority: an expired application/notice
/// deadline wins over a future event date. All comparisons use Karachi dates.
UniversityUpdateStatus universityUpdateStatus(
    Object? deadline, Object? eventDate, {DateTime? now}) {
  final instant = (now ?? DateTime.now()).toUtc()
      .add(const Duration(hours: 5));
  final today = '${instant.year.toString().padLeft(4, '0')}-'
      '${instant.month.toString().padLeft(2, '0')}-'
      '${instant.day.toString().padLeft(2, '0')}';
  final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  if (deadline is String && datePattern.hasMatch(deadline) &&
      deadline.compareTo(today) < 0) {
    return UniversityUpdateStatus.expired;
  }
  if (eventDate is String && datePattern.hasMatch(eventDate) &&
      eventDate.compareTo(today) > 0) {
    return UniversityUpdateStatus.upcoming;
  }
  return UniversityUpdateStatus.active;
}
