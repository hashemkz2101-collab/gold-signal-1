import '../models/candle.dart';

enum CandlePattern {
  pinBarBull,
  pinBarBear,
  engulfBull,
  engulfBear,
  rejectionBull,
  rejectionBear,
  strongBreakBull,
  strongBreakBear,
  insideBar,
}

const bullishPatterns = {
  CandlePattern.pinBarBull,
  CandlePattern.engulfBull,
  CandlePattern.rejectionBull,
  CandlePattern.strongBreakBull,
};

const bearishPatterns = {
  CandlePattern.pinBarBear,
  CandlePattern.engulfBear,
  CandlePattern.rejectionBear,
  CandlePattern.strongBreakBear,
};

/// Patterns formed by the LAST closed candle (and the one before it).
/// A pattern is only one input to a decision, never a reason by itself.
Set<CandlePattern> detectPatterns(List<Candle> cs, double atr) {
  final out = <CandlePattern>{};
  if (cs.length < 2 || atr <= 0) return out;
  final c = cs[cs.length - 1];
  final p = cs[cs.length - 2];
  final range = c.range;
  if (range <= 0) return out;

  final meaningful = range >= 0.4 * atr;

  if (meaningful) {
    if (c.lowerWick >= 2 * c.body &&
        c.lowerWick >= 0.55 * range &&
        c.upperWick <= 0.25 * range) {
      out.add(CandlePattern.pinBarBull);
    }
    if (c.upperWick >= 2 * c.body &&
        c.upperWick >= 0.55 * range &&
        c.lowerWick <= 0.25 * range) {
      out.add(CandlePattern.pinBarBear);
    }
    if (c.lowerWick >= 0.45 * range && c.close >= c.low + 0.6 * range) {
      out.add(CandlePattern.rejectionBull);
    }
    if (c.upperWick >= 0.45 * range && c.close <= c.high - 0.6 * range) {
      out.add(CandlePattern.rejectionBear);
    }
  }

  if (p.isBearish &&
      c.isBullish &&
      c.open <= p.close &&
      c.close >= p.open &&
      c.body > p.body) {
    out.add(CandlePattern.engulfBull);
  }
  if (p.isBullish &&
      c.isBearish &&
      c.open >= p.close &&
      c.close <= p.open &&
      c.body > p.body) {
    out.add(CandlePattern.engulfBear);
  }

  if (c.isBullish && c.body >= 1.3 * atr && c.upperWick <= 0.2 * c.body) {
    out.add(CandlePattern.strongBreakBull);
  }
  if (c.isBearish && c.body >= 1.3 * atr && c.lowerWick <= 0.2 * c.body) {
    out.add(CandlePattern.strongBreakBear);
  }

  if (c.high < p.high && c.low > p.low) out.add(CandlePattern.insideBar);
  return out;
}
