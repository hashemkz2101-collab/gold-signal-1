import 'dart:math' as math;

import '../core/models/candle.dart';
import '../core/models/quote.dart';
import '../core/models/timeframe.dart';
import 'market_data_provider.dart';

/// Synthetic random-walk data for UI/engine testing. Every quote is flagged
/// `isMock` and the source name says "داده آزمایشی". It is NOT market data.
class MockMarketDataProvider implements MarketDataProvider {
  MockMarketDataProvider({int seed = 42, this.startPrice = 4000})
      : _rng = math.Random(seed);

  final math.Random _rng;
  final double startPrice;
  final List<Candle> _m1 = [];

  static const sourceName = 'داده آزمایشی';

  @override
  String get name => sourceName;

  @override
  bool get isMock => true;

  double _gauss() {
    final u1 = 1 - _rng.nextDouble();
    final u2 = _rng.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  DateTime _lastClosedMinute(DateTime now) {
    final u = now.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute)
        .subtract(const Duration(minutes: 1));
  }

  void _extend(DateTime now) {
    final target = _lastClosedMinute(now);
    if (_m1.isEmpty) {
      var t = target.subtract(const Duration(minutes: 4500));
      var p = startPrice;
      while (!t.isAfter(target)) {
        final c = _next(t, p);
        _m1.add(c);
        p = c.close;
        t = t.add(const Duration(minutes: 1));
      }
      return;
    }
    var t = _m1.last.time.add(const Duration(minutes: 1));
    var p = _m1.last.close;
    while (!t.isAfter(target)) {
      final c = _next(t, p);
      _m1.add(c);
      p = c.close;
      t = t.add(const Duration(minutes: 1));
    }
    if (_m1.length > 7000) _m1.removeRange(0, _m1.length - 7000);
  }

  Candle _next(DateTime t, double p) {
    final regime = math.sin(t.millisecondsSinceEpoch / 3600000.0) * 0.08;
    final move = _gauss() * 0.6 + regime;
    final close = p + move;
    final high = math.max(p, close) + _rng.nextDouble() * 0.3;
    final low = math.min(p, close) - _rng.nextDouble() * 0.3;
    return Candle(
        time: t,
        open: p,
        high: high,
        low: low,
        close: close,
        volume: 50 + _rng.nextDouble() * 100);
  }

  @override
  Future<Quote> fetchQuote() async {
    final now = DateTime.now().toUtc();
    _extend(now);
    final last = _m1.last.close + _gauss() * 0.05;
    // Mid only: a mock must not pretend to have a real Bid/Ask pair.
    return Quote(mid: last, time: now, source: sourceName, isMock: true);
  }

  @override
  Future<List<Candle>> fetchCandles(Timeframe tf, {int count = 300}) async {
    _extend(DateTime.now().toUtc());
    final list = aggregateCandles(_m1, tf.minutes);
    return list.length > count ? list.sublist(list.length - count) : list;
  }
}
