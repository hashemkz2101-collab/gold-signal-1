import 'dart:math' as math;

import '../models/candle.dart';
import '../models/timeframe.dart';
import 'structure.dart';

enum LevelType { swing, demand, supply }

/// A support/resistance/supply/demand price ZONE.
/// Whether it acts as support or resistance depends on where price is
/// relative to it, so that is decided at query time.
class PriceLevel {
  const PriceLevel({
    required this.low,
    required this.high,
    required this.type,
    required this.timeframe,
    required this.touches,
    required this.createdAt,
    required this.strength,
  });

  final double low;
  final double high;
  final LevelType type;
  final Timeframe timeframe;
  final int touches;
  final DateTime createdAt;

  /// 0..1 validity/importance.
  final double strength;

  double get mid => (low + high) / 2;

  /// Distance from [price] to the zone (0 if inside).
  double distanceFrom(double price) {
    if (price < low) return low - price;
    if (price > high) return price - high;
    return 0;
  }
}

int _visits(List<Candle> cs, int from, double low, double high) {
  var visits = 0;
  var inside = false;
  for (var i = math.max(0, from); i < cs.length; i++) {
    final touching = cs[i].low <= high && cs[i].high >= low;
    if (touching && !inside) visits++;
    inside = touching;
  }
  return visits;
}

/// Clusters swing prices into zones. Cluster tolerance is `tolAtr * atr`.
List<PriceLevel> detectSwingLevels(
  Timeframe tf,
  List<Candle> cs,
  List<Swing> swings,
  double atr, {
  double tolAtr = 0.5,
}) {
  if (swings.isEmpty || atr <= 0) return const [];
  final tol = tolAtr * atr;
  final sorted = List<Swing>.of(swings)
    ..sort((a, b) => a.price.compareTo(b.price));
  final groups = <List<Swing>>[];
  for (final s in sorted) {
    if (groups.isNotEmpty && s.price - groups.last.last.price <= tol) {
      groups.last.add(s);
    } else {
      groups.add([s]);
    }
  }
  final out = <PriceLevel>[];
  for (final g in groups) {
    var low = g.first.price;
    var high = g.last.price;
    if (high - low < 0.1 * atr) {
      final c = (low + high) / 2;
      low = c - 0.05 * atr;
      high = c + 0.05 * atr;
    }
    final firstIdx = g.map((s) => s.index).reduce(math.min);
    final touches = math.max(g.length, _visits(cs, firstIdx, low, high));
    final strength =
        math.min(1.0, touches / 4.0) * (0.4 + 0.6 * tf.weight);
    out.add(PriceLevel(
      low: low,
      high: high,
      type: LevelType.swing,
      timeframe: tf,
      touches: touches,
      createdAt: cs[firstIdx].time,
      strength: strength,
    ));
  }
  return out;
}

/// Supply/demand zones from a small "base" candle followed by an impulsive
/// candle. Zones price has closed through are dropped; zones retested several
/// times lose strength.
List<PriceLevel> detectSupplyDemand(
    Timeframe tf, List<Candle> cs, double atr) {
  final out = <PriceLevel>[];
  if (atr <= 0) return out;
  for (var i = 1; i < cs.length - 2; i++) {
    final base = cs[i];
    final imp = cs[i + 1];
    if (base.range > 0.7 * atr) continue;
    final demand =
        imp.isBullish && imp.body >= 1.2 * atr && imp.close > base.high;
    final supply =
        imp.isBearish && imp.body >= 1.2 * atr && imp.close < base.low;
    if (!demand && !supply) continue;

    final low = base.low;
    final high = base.high;
    var broken = false;
    for (var k = i + 2; k < cs.length; k++) {
      if (demand ? cs[k].close < low : cs[k].close > high) {
        broken = true;
        break;
      }
    }
    if (broken) continue;
    final visits = _visits(cs, i + 2, low, high);
    final strength =
        ((1 - 0.3 * visits).clamp(0.0, 1.0) * (0.4 + 0.6 * tf.weight)).toDouble();
    if (strength <= 0.05) continue;
    out.add(PriceLevel(
      low: low,
      high: high,
      type: demand ? LevelType.demand : LevelType.supply,
      timeframe: tf,
      touches: visits,
      createdAt: base.time,
      strength: strength,
    ));
  }
  return out;
}
