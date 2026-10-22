import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/indicators/indicators.dart';
import 'package:gold_signal_assistant/core/models/candle.dart';

Candle c(int i, double o, double h, double l, double cl) => Candle(
      time: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
      open: o,
      high: h,
      low: l,
      close: cl,
    );

void main() {
  test('EMA is null before the seed and equals SMA at the seed', () {
    final out = ema([1, 2, 3, 4, 5], 3);
    expect(out[0], isNull);
    expect(out[1], isNull);
    expect(out[2], closeTo(2.0, 1e-12));
    // k = 0.5 -> 4*0.5 + 2*0.5 = 3
    expect(out[3], closeTo(3.0, 1e-12));
    expect(out[4], closeTo(4.0, 1e-12));
  });

  test('EMA of a constant series is that constant', () {
    final out = ema(List.filled(30, 7.5), 10);
    expect(out.last, closeTo(7.5, 1e-12));
  });

  test('RSI of a strictly rising series is 100, falling is 0', () {
    final up = rsi(List.generate(30, (i) => 100.0 + i), 14);
    final down = rsi(List.generate(30, (i) => 100.0 - i), 14);
    expect(up.last, closeTo(100, 1e-9));
    expect(down.last, closeTo(0, 1e-9));
    expect(up[13], isNull);
    expect(up[14], isNotNull);
  });

  test('ATR of identical ranges equals the range', () {
    final cs = List.generate(30, (i) => c(i, 100, 101, 99, 100));
    final out = atr(cs, 14);
    expect(out[12], isNull);
    expect(out[13], closeTo(2.0, 1e-12));
    expect(out.last, closeTo(2.0, 1e-12));
  });

  test('ATR uses gaps via true range', () {
    final cs = [
      c(0, 100, 101, 99, 100),
      c(1, 110, 111, 109, 110), // gap up: TR = |111-100| = 11
    ];
    final out = atr(cs, 2);
    expect(out[1], closeTo((2 + 11) / 2, 1e-12));
  });

  test('median', () {
    expect(median([3, 1, 2]), 2);
    expect(median([4, 1, 3, 2]), 2.5);
    expect(median([]), 0);
  });
}
