/// Formats a date as `10th Sept, 2026`.
String formatFriendlyDate(DateTime value) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'June',
    'July',
    'Aug',
    'Sept',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${value.day}${_ordinalSuffix(value.day)} '
      '${months[value.month - 1]}, ${value.year}';
}

/// Formats a date and time as `10th Sept, 2026 • 2:30 PM`.
String formatFriendlyDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${formatFriendlyDate(local)} • $hour:$minute $period';
}

/// Formats ISO date strings while leaving labels such as `Week 37` unchanged.
String formatFriendlyDateValue(
  Object? value, {
  String fallback = 'Not recorded',
}) {
  if (value is DateTime) return formatFriendlyDate(value.toLocal());
  if (value is String) {
    if (value.trim().isEmpty) return fallback;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : formatFriendlyDate(parsed.toLocal());
  }
  return fallback;
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  return switch (day % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}
