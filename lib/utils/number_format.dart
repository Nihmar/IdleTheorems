import 'dart:math';

/// Shared number formatting for the whole game.
///
/// Idle progression reaches far beyond what plain integers read well, so all
/// player-facing values MUST go through [formatNumber] / [formatRate] instead
/// of raw `toString()`. Supports the full useful range of `double`:
/// compact suffixes up to decillion, then scientific notation.

const List<String> _suffixes = [
  '', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc', 'No', 'Dc',
  'UDc', 'DDc', 'TDc', 'QaDc', 'QiDc', 'SxDc', 'SpDc', 'OcDc', 'NoDc', 'VDc',
];

/// Formats [value] compactly: `1234` -> `1.23K`, `5.6e21` -> `5.60Yd`-style
/// tier names where available, scientific beyond that.
String formatNumber(double value) {
  if (value.isNaN || value.isInfinite) return '\u221e';
  final negative = value < 0;
  var v = value.abs();

  String body;
  if (v < 1000) {
    // Small numbers keep at most two decimals, drop trailing zeros.
    body = v == v.truncateToDouble()
        ? v.toStringAsFixed(0)
        : _trimZeros(v.toStringAsFixed(v < 10 ? 2 : 1));
  } else if ((log10Of(v) ~/ 3) >= _suffixes.length) {
    // Beyond the last named tier: scientific notation.
    return _signed(negative, v.toStringAsExponential(2));
  } else {
    final tier = log10Of(v) ~/ 3;
    final scaled = v / pow10(tier * 3);
    body = '${_trimZeros(scaled.toStringAsFixed(2))}${_suffixes[tier]}';
  }
  return _signed(negative, body);
}

/// Formats a per-second rate.
String formatRate(double valuePerSec) => '${formatNumber(valuePerSec)}/s';

String _signed(bool negative, String body) => negative ? '-$body' : body;

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  var t = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return t.endsWith('.') ? t.substring(0, t.length - 1) : t;
}

int log10Of(double v) => (log(v) / log(10)).floor();

double pow10(int e) => pow(10.0, e).toDouble();
