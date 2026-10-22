import 'dart:math' as math;

import '../models/candle.dart';

/// EMA seeded with the SMA of the first [period] values.
/// Entries before the seed index are null.
List<double?> ema(List<double> values, int period) {
  final out = List<double?>.filled(values.length, null);
  if (period <= 0 || values.length < period) return out;
  var sum = 0.0;
  for (var i = 0; i < period; i++) {
    sum += values[i];
  }
  var prev = sum / period;
  out[period - 1] = prev;
  final k = 2 / (period + 1);
  for (var i = period; i < values.length; i++) {
    prev = values[i] * k + prev * (1 - k);
    out[i] = prev;
  }
  return out;
}

/// Wilder RSI. First value is at index [period].
List<double?> rsi(List<double> closes, int period) {
  final out = List<double?>.filled(closes.length, null);
  if (period <= 0 || closes.length <= period) return out;
  var gain = 0.0, loss = 0.0;
  for (var i = 1; i <= period; i++) {
    final d = closes[i] - closes[i - 1];
    if (d >= 0) {
      gain += d;
    } else {
      loss -= d;
    }
  }
  var avgGain = gain / period;
  var avgLoss = loss / period;
  double value(double g, double l) => l == 0 ? 100.0 : 100 - 100 / (1 + g / l);
  out[period] = value(avgGain, avgLoss);
  for (var i = period + 1; i < closes.length; i++) {
    final d = closes[i] - closes[i - 1];
    final g = d > 0 ? d : 0.0;
    final l = d < 0 ? -d : 0.0;
    avgGain = (avgGain * (period - 1) + g) / period;
    avgLoss = (avgLoss * (period - 1) + l) / period;
    out[i] = value(avgGain, avgLoss);
  }
  return out;
}

/// Wilder ATR. First value is at index `period - 1`.
List<double?> atr(List<Candle> candles, int period) {
  final out = List<double?>.filled(candles.length, null);
  if (period <= 0 || candles.length < period) return out;
  final tr = List<double>.filled(candles.length, 0);
  tr[0] = candles[0].high - candles[0].low;
  for (var i = 1; i < candles.length; i++) {
    final c = candles[i];
    final pc = candles[i - 1].close;
    tr[i] = math.max(c.high - c.low,
        math.max((c.high - pc).abs(), (c.low - pc).abs()));
  }
  var sum = 0.0;
  for (var i = 0; i < period; i++) {
    sum += tr[i];
  }
  var prev = sum / period;
  out[period - 1] = prev;
  for (var i = period; i < candles.length; i++) {
    prev = (prev * (period - 1) + tr[i]) / period;
    out[i] = prev;
  }
  return out;
}

double? lastValue(List<double?> series) {
  for (var i = series.length - 1; i >= 0; i--) {
    final v = series[i];
    if (v != null) return v;
  }
  return null;
}

double median(List<double> values) {
  if (values.isEmpty) return 0;
  final s = List<double>.of(values)..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}
