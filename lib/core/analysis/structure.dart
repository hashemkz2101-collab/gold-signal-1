import '../models/candle.dart';

/// A confirmed swing point. It only becomes known at [confirmedIndex]
/// (= index + strength), so using it never leaks future data.
class Swing {
  const Swing({
    required this.index,
    required this.price,
    required this.isHigh,
    required this.time,
    required this.confirmedIndex,
  });

  final int index;
  final double price;
  final bool isHigh;
  final DateTime time;
  final int confirmedIndex;
}

/// Swing high: strictly higher than the [n] candles on the left and not lower
/// than the [n] candles on the right. Symmetric for swing lows. Candles in the
/// last [n] positions can never be swings (not confirmed yet).
List<Swing> detectSwings(List<Candle> cs, {int n = 3}) {
  final out = <Swing>[];
  if (n < 1) return out;
  for (var i = n; i < cs.length - n; i++) {
    var isHigh = true;
    var isLow = true;
    for (var k = 1; k <= n; k++) {
      if (cs[i].high <= cs[i - k].high || cs[i].high < cs[i + k].high) {
        isHigh = false;
      }
      if (cs[i].low >= cs[i - k].low || cs[i].low > cs[i + k].low) {
        isLow = false;
      }
    }
    if (isHigh) {
      out.add(Swing(
          index: i,
          price: cs[i].high,
          isHigh: true,
          time: cs[i].time,
          confirmedIndex: i + n));
    }
    if (isLow) {
      out.add(Swing(
          index: i,
          price: cs[i].low,
          isHigh: false,
          time: cs[i].time,
          confirmedIndex: i + n));
    }
  }
  return out;
}

enum Trend { up, down, range }

class MarketStructure {
  const MarketStructure({
    required this.trend,
    this.lastHigh,
    this.prevHigh,
    this.lastLow,
    this.prevLow,
    this.bosUp = false,
    this.bosDown = false,
    this.chochUp = false,
    this.chochDown = false,
  });

  final Trend trend;
  final Swing? lastHigh;
  final Swing? prevHigh;
  final Swing? lastLow;
  final Swing? prevLow;

  /// Break of structure in the trend direction (close beyond last swing).
  final bool bosUp;
  final bool bosDown;

  /// Change of character: break against the prevailing trend.
  final bool chochUp;
  final bool chochDown;

  bool get hasBreakUp => bosUp || chochUp;
  bool get hasBreakDown => bosDown || chochDown;
}

/// Classifies trend from the last two swing highs/lows and flags fresh breaks.
/// A break counts only on a candle CLOSE and only if price was on the other
/// side of the level within the last [lookback] candles (so an old, long-ago
/// break is not reported again).
MarketStructure analyzeStructure(List<Candle> cs, List<Swing> swings,
    {int lookback = 5}) {
  final highs = swings.where((s) => s.isHigh).toList();
  final lows = swings.where((s) => !s.isHigh).toList();
  final lh = highs.isNotEmpty ? highs.last : null;
  final ph = highs.length >= 2 ? highs[highs.length - 2] : null;
  final ll = lows.isNotEmpty ? lows.last : null;
  final pl = lows.length >= 2 ? lows[lows.length - 2] : null;

  var trend = Trend.range;
  if (lh != null && ph != null && ll != null && pl != null) {
    final hh = lh.price > ph.price;
    final hl = ll.price > pl.price;
    if (hh && hl) {
      trend = Trend.up;
    } else if (!hh && !hl) {
      trend = Trend.down;
    }
  }

  var bosUp = false, bosDown = false, chochUp = false, chochDown = false;
  if (cs.length > 1) {
    final last = cs.last.close;
    final from = (cs.length - 1 - lookback).clamp(0, cs.length - 1).toInt();

    bool wasOtherSide(double level, bool below) {
      for (var i = from; i < cs.length - 1; i++) {
        if (below ? cs[i].close <= level : cs[i].close >= level) return true;
      }
      return false;
    }

    if (lh != null && last > lh.price && wasOtherSide(lh.price, true)) {
      if (trend == Trend.down) {
        chochUp = true;
      } else {
        bosUp = true;
      }
    }
    if (ll != null && last < ll.price && wasOtherSide(ll.price, false)) {
      if (trend == Trend.up) {
        chochDown = true;
      } else {
        bosDown = true;
      }
    }
  }

  return MarketStructure(
    trend: trend,
    lastHigh: lh,
    prevHigh: ph,
    lastLow: ll,
    prevLow: pl,
    bosUp: bosUp,
    bosDown: bosDown,
    chochUp: chochUp,
    chochDown: chochDown,
  );
}
