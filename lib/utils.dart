String formatDeadline(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final time = '${two(d.hour)}:${two(d.minute)}';
  if (diff == 0) return 'Бүгін, $time';
  if (diff == 1) return 'Ертең, $time';
  if (diff == -1) return 'Кеше, $time';
  return '${two(d.day)}.${two(d.month)}.${d.year}, $time';
}

String kzDateLabel(DateTime d) {
  const weekdays = [
    'Дүйсенбі',
    'Сейсенбі',
    'Сәрсенбі',
    'Бейсенбі',
    'Жұма',
    'Сенбі',
    'Жексенбі',
  ];
  const months = [
    'қаңтар',
    'ақпан',
    'наурыз',
    'сәуір',
    'мамыр',
    'маусым',
    'шілде',
    'тамыз',
    'қыркүйек',
    'қазан',
    'қараша',
    'желтоқсан',
  ];
  return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}
