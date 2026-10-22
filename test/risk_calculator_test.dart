import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/models/signal.dart';
import 'package:gold_signal_assistant/core/risk/risk_calculator.dart';

void main() {
  const lots = 0.01;
  const contract = 100.0;

  test('price risk for 0.01 lot: 1 USD move = 1 USD', () {
    expect(RiskCalculator.usdPerDollarMove(lots, contract), closeTo(1.0, 1e-12));
    expect(
      RiskCalculator.priceRisk(
          entry: 4000, stop: 3995, lots: lots, contractSize: contract),
      closeTo(5.0, 1e-9),
    );
  });

  test('spec example: R=5, C=2 -> net loss 7, net target 21, gross 23', () {
    expect(RiskCalculator.netLoss(5, 2), closeTo(7, 1e-12));
    expect(RiskCalculator.netTarget(5, 2), closeTo(21, 1e-12));
    expect(RiskCalculator.grossTarget(5, 2), closeTo(23, 1e-12));
  });

  test('target price: buy above entry, sell below entry', () {
    final buy = RiskCalculator.targetPrice(
        side: Side.buy,
        entry: 4000,
        priceRisk: 5,
        cost: 2,
        lots: lots,
        contractSize: contract);
    final sell = RiskCalculator.targetPrice(
        side: Side.sell,
        entry: 4000,
        priceRisk: 5,
        cost: 2,
        lots: lots,
        contractSize: contract);
    expect(buy, closeTo(4023, 1e-9));
    expect(sell, closeTo(3977, 1e-9));
  });

  test('net R:R of the computed target is exactly 3', () {
    final target = RiskCalculator.targetPrice(
        side: Side.buy,
        entry: 4000,
        priceRisk: 5,
        cost: 2,
        lots: lots,
        contractSize: contract);
    final rr = RiskCalculator.netRR(
        entry: 4000,
        stop: 3995,
        target: target,
        lots: lots,
        contractSize: contract,
        cost: 2);
    expect(rr, closeTo(3.0, 1e-9));
  });

  test('a target giving gross 1:3 is NOT net 1:3 once cost is counted', () {
    final rr = RiskCalculator.netRR(
        entry: 4000,
        stop: 3995,
        target: 4015,
        lots: lots,
        contractSize: contract,
        cost: 2);
    expect(rr, lessThan(3.0));
    expect(rr, closeTo((15 - 2) / 7, 1e-9));
  });

  test('risk classification', () {
    expect(
        RiskCalculator.classify(
            priceRisk: 5, normalMax: 5, specialMax: 10, allowSpecial: false),
        RiskClass.normal);
    expect(
        RiskCalculator.classify(
            priceRisk: 7, normalMax: 5, specialMax: 10, allowSpecial: false),
        isNull);
    expect(
        RiskCalculator.classify(
            priceRisk: 7, normalMax: 5, specialMax: 10, allowSpecial: true),
        RiskClass.high);
    expect(
        RiskCalculator.classify(
            priceRisk: 10.5, normalMax: 5, specialMax: 10, allowSpecial: true),
        isNull);
  });

  test('margin example from spec: 4000 x 100 x 0.01 x 0.2% = 8', () {
    expect(
      RiskCalculator.margin(
          price: 4000, lots: 0.01, contractSize: 100, marginPercent: 0.2),
      closeTo(8.0, 1e-9),
    );
  });

  test('volume scales risk linearly (engine must not auto-resize it)', () {
    expect(
      RiskCalculator.priceRisk(
          entry: 4000, stop: 3995, lots: 0.02, contractSize: contract),
      closeTo(10.0, 1e-9),
    );
  });
}
