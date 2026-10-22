import '../models/signal.dart';

/// Pure money-management maths. All amounts are USD for a USD account with a
/// USD-quoted symbol (XAUUSD). Contract size and lots are inputs, never
/// hard-coded.
///
/// Definitions (R = price risk, C = estimated round-trip cost):
///   net planned loss   = R + C
///   net planned profit = rr * (R + C)
///   gross price target = rr * (R + C) + C      (so that profit AFTER cost is rr x net loss)
class RiskCalculator {
  const RiskCalculator._();

  /// USD gained/lost per 1.00 USD move in the gold price.
  static double usdPerDollarMove(double lots, double contractSize) =>
      lots * contractSize;

  /// R: loss caused only by price travelling from [entry] to [stop].
  static double priceRisk({
    required double entry,
    required double stop,
    required double lots,
    required double contractSize,
  }) =>
      (entry - stop).abs() * usdPerDollarMove(lots, contractSize);

  static double netLoss(double priceRisk, double cost) => priceRisk + cost;

  static double netTarget(double priceRisk, double cost, {double rr = 3}) =>
      rr * (priceRisk + cost);

  static double grossTarget(double priceRisk, double cost, {double rr = 3}) =>
      rr * (priceRisk + cost) + cost;

  /// Take-profit price giving a net reward:risk of [rr] after [cost].
  static double targetPrice({
    required Side side,
    required double entry,
    required double priceRisk,
    required double cost,
    required double lots,
    required double contractSize,
    double rr = 3,
  }) {
    final distance = grossTarget(priceRisk, cost, rr: rr) /
        usdPerDollarMove(lots, contractSize);
    return side == Side.buy ? entry + distance : entry - distance;
  }

  /// Net reward:risk of a concrete plan, after subtracting [cost] once.
  static double netRR({
    required double entry,
    required double stop,
    required double target,
    required double lots,
    required double contractSize,
    required double cost,
  }) {
    final perUnit = usdPerDollarMove(lots, contractSize);
    final risk = (entry - stop).abs() * perUnit;
    final grossReward = (target - entry).abs() * perUnit;
    final denom = risk + cost;
    if (denom <= 0) return 0;
    return (grossReward - cost) / denom;
  }

  /// Null means the risk is above every allowed ceiling.
  static RiskClass? classify({
    required double priceRisk,
    required double normalMax,
    required double specialMax,
    required bool allowSpecial,
  }) {
    if (priceRisk <= normalMax + 1e-9) return RiskClass.normal;
    if (allowSpecial && priceRisk <= specialMax + 1e-9) return RiskClass.high;
    return null;
  }

  /// Approximate required margin. [marginPercent] 0.2 means 0.2 %.
  static double margin({
    required double price,
    required double lots,
    required double contractSize,
    required double marginPercent,
  }) =>
      price * contractSize * lots * (marginPercent / 100);
}
