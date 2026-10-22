import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/models/candle.dart';

void main() {
  List<Candle> m1(int count, {int startMinute = 0}) => [
        for (var i = 0; i < count; i++)
          Candle(
            time: DateTime.utc(2026, 1, 1, 0, startMinute + i),
            open: 100.0 + i,
            high: 101.0 + i,
            low: 99.0 + i,
            close: 100.5 + i,
            volume: 1,
          ),
      ];

  test('5 one-minute candles make one M5 candle with correct OHLCV', () {
    final out = aggregateCandles(m1(5), 5);
    expect(out.length, 1);
    expect(out.first.open, 100);
    expect(out.first.high, 105);
    expect(out.first.low, 99);
    expect(out.first.close, 104.5);
    expect(out.first.volume, 5);
    expect(out.first.time, DateTime.utc(2026, 1, 1, 0, 0));
  });

  test('the last incomplete bucket is dropped', () {
    final out = aggregateCandles(m1(8), 5);
    expect(out.length, 1);
  });

  test('buckets align to the clock; a leading partial bucket is dropped', () {
    // minutes 3..14 -> bucket 0 has only minutes 3,4 (dropped), then 5 and 10.
    final out = aggregateCandles(m1(12, startMinute: 3), 5);
    expect(out.map((c) => c.time.minute).toList(), [5, 10]);
  });
}
