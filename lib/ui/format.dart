String fmt(double v, [int digits = 2]) => v.toStringAsFixed(digits);

String two(int v) => v.toString().padLeft(2, '0');

String hms(DateTime t) {
  final l = t.toLocal();
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

String hm(DateTime t) {
  final l = t.toLocal();
  return '${two(l.hour)}:${two(l.minute)}';
}
