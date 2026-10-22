import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/analysis/structure.dart';
import 'package:gold_signal_assistant/core/models/candle.dart';

Candle k(int i, double high, double low, [double? close]) => Candle(
      time: DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
      open: (high + low) / 2,
      high: high,
      low: low,
      close: close ?? (high + low) / 2,
    );

void main() {
  test('swing high needs n lower candles on both sides', () {
    // peak at index 3
    final highs = <double>[10, 11, 12, 15, 12, 11, 10];
    final cs = [for (var i = 0; i < highs.length; i++) k(i, highs[i], highs[i] - 1)];
    final swings = detectSwings(cs, n: 3);
    final sh = swings.where((s) => s.isHigh).toList();
    expect(sh.length, 1);
    expect(sh.first.index, 3);
    expect(sh.first.price, 15);
    expect(sh.first.confirmedIndex, 6);
  });

  test('no swing can sit in the last n candles (no look-ahead)', () {
    final highs = <double>[10, 11, 12, 13, 14, 15, 16, 20];
    final cs = [for (var i = 0; i < highs.length; i++) k(i, highs[i], highs[i] - 1)];
    final swings = detectSwings(cs, n: 3);
    for (final s in swings) {
      expect(s.confirmedIndex, lessThanOrEqualTo(cs.length - 1));
    }
    expect(swings.where((s) => s.isHigh && s.index == cs.length - 1), isEmpty);
  });

  test('swing low detection', () {
    final lows = <double>[20, 19, 18, 12, 18, 19, 20];
    final cs = [for (var i = 0; i < lows.length; i++) k(i, lows[i] + 1, lows[i])];
    final sl = detectSwings(cs, n: 3).where((s) => !s.isHigh).toList();
    expect(sl.length, 1);
    expect(sl.first.index, 3);
    expect(sl.first.price, 12);
  });

  test('HH + HL is an uptrend, LH + LL is a downtrend', () {
    Swing s(int i, double p, bool high) => Swing(
        index: i,
        price: p,
        isHigh: high,
        time: DateTime.utc(2026),
        confirmedIndex: i + 3);
    final flat = [k(0, 10, 9), k(1, 10, 9)];
    final up = analyzeStructure(
        flat, [s(1, 10, true), s(2, 5, false), s(3, 12, true), s(4, 7, false)]);
    final down = analyzeStructure(
        flat, [s(1, 12, true), s(2, 7, false), s(3, 10, true), s(4, 5, false)]);
    final range = analyzeStructure(
        flat, [s(1, 10, true), s(2, 5, false), s(3, 12, true), s(4, 4, false)]);
    expect(up.trend, Trend.up);
    expect(down.trend, Trend.down);
    expect(range.trend, Trend.range);
  });

  test('a CLOSE above the last swing high right after being below = fresh break', () {
    Swing s(int i, double p, bool high) => Swing(
        index: i,
        price: p,
        isHigh: high,
        time: DateTime.utc(2026),
        confirmedIndex: i + 3);
    final cs = [
      k(0, 10, 9, 9.5),
      k(1, 10, 9, 9.6),
      k(2, 12, 10, 11.5), // closes above 11
    ];
    final r = analyzeStructure(cs, [s(0, 11, true), s(1, 8, false)]);
    expect(r.hasBreakUp, isTrue);
    expect(r.hasBreakDown, isFalse);
  });

  test('a wick through the level without a close is NOT a break', () {
    Swing s(int i, double p, bool high) => Swing(
        index: i,
        price: p,
        isHigh: high,
        time: DateTime.utc(2026),
        confirmedIndex: i + 3);
    final cs = [
      k(0, 10, 9, 9.5),
      k(1, 10, 9, 9.6),
      k(2, 12, 9, 9.8), // spikes above 11 but closes below
    ];
    final r = analyzeStructure(cs, [s(0, 11, true), s(1, 8, false)]);
    expect(r.hasBreakUp, isFalse);
  });
}
