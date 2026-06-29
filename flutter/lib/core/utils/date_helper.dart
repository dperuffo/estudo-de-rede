String dataBr(dynamic data, {bool comHora = false}) {
  if (data == null || data.toString().isEmpty) return '-';
  try {
    final dt = DateTime.parse(data.toString()).toLocal();
    final d = '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
    if (!comHora) return d;
    final h = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d $h';
  } catch (_) {
    return data.toString().length >= 10 ? data.toString().substring(0,10) : data.toString();
  }
}
