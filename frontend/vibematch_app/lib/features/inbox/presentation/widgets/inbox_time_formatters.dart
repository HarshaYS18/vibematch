String inboxLocalTimeLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return value;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return value;

  final local = parsed.toLocal();
  final now = DateTime.now();
  final time = _format12h(local);
  if (_sameDate(local, now)) return time;

  final yesterday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 1));
  if (_sameDate(local, yesterday)) return 'Yesterday $time';

  return '${_month(local.month)} ${local.day}, $time';
}

bool _sameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _format12h(DateTime value) {
  final suffix = value.hour < 12 ? 'am' : 'pm';
  var hour = value.hour % 12;
  if (hour == 0) hour = 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $suffix';
}

String _month(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  if (month < 1 || month > 12) return '';
  return months[month - 1];
}
