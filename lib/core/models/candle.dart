import 'dart:math' as math;

/// A CLOSED candle. [time] is the candle open time in UTC.
class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  double get body => (close - open).abs();
  double get range => high - low;
  double get upperWick => high - math.max(open, close);
  double get lowerWick => math.min(open, close) - low;
  bool get isBullish => close > open;
  bool get isBearish => close < open;

  Map<String, Object?> toJson() => {
        't': time.millisecondsSinceEpoch,
        'o': open,
        'h': high,
        'l': low,
        'c': close,
        'v': volume,
      };

  factory Candle.fromJson(Map<String, dynamic> j) => Candle(
        time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int, isUtc: true),
        open: (j['o'] as num).toDouble(),
        high: (j['h'] as num).toDouble(),
        low: (j['l'] as num).toDouble(),
        close: (j['c'] as num).toDouble(),
        volume: (j['v'] as num?)?.toDouble() ?? 0,
      );
}

/// Builds higher-timeframe candles from 1-minute candles (ascending order).
/// A leading bucket that starts mid-period and a trailing bucket that is not
/// finished yet are both dropped, so every returned candle is complete.
List<Candle> aggregateCandles(List<Candle> m1, int minutes) {
  if (m1.isEmpty || minutes <= 1) return List<Candle>.of(m1);
  final bucketMs = minutes * 60000;
  final out = <Candle>[];
  int? currentKey;
  late DateTime start;
  var o = 0.0, h = 0.0, l = 0.0, c = 0.0, v = 0.0;
  var lastTime = m1.first.time;
  var isFirstBucket = true;
  final leadingPartial = m1.first.time.millisecondsSinceEpoch % bucketMs != 0;

  void flush(bool complete) {
    if (currentKey == null || !complete) return;
    if (isFirstBucket && leadingPartial) return;
    out.add(Candle(time: start, open: o, high: h, low: l, close: c, volume: v));
  }

  for (final k in m1) {
    final key = k.time.millisecondsSinceEpoch ~/ bucketMs;
    if (key != currentKey) {
      flush(true);
      if (currentKey != null) isFirstBucket = false;
      currentKey = key;
      start = DateTime.fromMillisecondsSinceEpoch(key * bucketMs, isUtc: true);
      o = k.open;
      h = k.high;
      l = k.low;
      c = k.close;
      v = k.volume;
    } else {
      h = math.max(h, k.high);
      l = math.min(l, k.low);
      c = k.close;
      v += k.volume;
    }
    lastTime = k.time;
  }
  final lastBucketEnd = start.add(Duration(minutes: minutes - 1));
  flush(!lastTime.isBefore(lastBucketEnd));
  return out;
}
