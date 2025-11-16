String formatCount(num value) {
  final n = value.abs();
  String suffix;
  double numPart;
  if (n < 1000) {
    return value.toStringAsFixed(0);
  } else if (n < 1000000) {
    numPart = value / 1000.0;
    suffix = 'K';
  } else if (n < 1000000000) {
    numPart = value / 1000000.0;
    suffix = 'M';
  } else {
    numPart = value / 1000000000.0;
    suffix = 'B';
  }
  String s = numPart.toStringAsFixed(1);
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return '$s$suffix';
}
