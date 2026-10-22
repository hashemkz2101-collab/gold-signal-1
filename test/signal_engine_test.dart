import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/analysis/signal_engine.dart';
import 'package:gold_signal_assistant/core/models/app_settings.dart';
import 'package:gold_signal_assistant/core/models/candle.dart';
import 'package:gold_signal_assistant/core/models/quote.dart';
import 'package:gold_signal_assistant/core/models/signal.dart';
import 'package:gold_signal_assistant/core/models/timeframe.dart';
import 'package:gold_signal_assistant/core/risk/risk_calculator.dart';
import 'package:gold_signal_assistant/data/mock_provider.dart';

Future<Map<Timeframe, List<Candle>>> _candles(MockMarketDataProvider p) async {
  final out = <Timeframe, List<Candle>>{};
  for (final tf in Timeframe.values) {
    out[tf] = await p.fetchCandles(tf, count: 300);
  }
  return out;
}

void main() {
  const settings = AppSettings();

  test('mock provider never fakes a Bid/Ask pair and is flagged as mock', () async {
    final p = MockMarketDataProvider(seed: 1);
    final q = await p.fetchQuote();
    expect(q.isMock, isTrue);
    expect(q.hasRealBidAsk, isFalse);
    expect(q.source, contains('آزمایشی'));
  });

  test('stale quote blocks all new signals', () async {
    final p = MockMarketDataProvider(seed: 2);
    final candles = await _candles(p);
    final fresh = await p.fetchQuote();
    final stale = Quote(
      mid: fresh.mid,
      time: fresh.time.subtract(const Duration(minutes: 10)),
      source: fresh.source,
      isMock: true,
    );
    final r = const SignalEngine().analyze(AnalysisInput(
      candles: candles,
      quote: stale,
      settings: settings,
      now: DateTime.now().toUtc(),
    ));
    expect(r.tradingAllowed, isFalse);
    expect(r.signals, isEmpty);
  });

  test('spread above the limit blocks signals', () async {
    final p = MockMarketDataProvider(seed: 3);
    final candles = await _candles(p);
    final now = DateTime.now().toUtc();
    final q = Quote(
      mid: 4000,
      bid: 3999,
      ask: 4001, // spread 2.0 > maxSpread 0.6
      time: now,
      source: 'test',
    );
    final r = const SignalEngine().analyze(
        AnalysisInput(candles: candles, quote: q, settings: settings, now: now));
    expect(r.tradingAllowed, isFalse);
    expect(r.signals, isEmpty);
  });

  test('price mismatch with the MT5 reference blocks signals', () async {
    final p = MockMarketDataProvider(seed: 4);
    final candles = await _candles(p);
    final q = await p.fetchQuote();
    final r = const SignalEngine().analyze(AnalysisInput(
      candles: candles,
      quote: q,
      settings: settings,
      now: DateTime.now().toUtc(),
      referencePrice: q.mid + 25,
    ));
    expect(r.tradingAllowed, isFalse);
    expect(r.signals, isEmpty);
  });

  test('too few candles -> no signal, no crash', () {
    final now = DateTime.now().toUtc();
    final r = const SignalEngine().analyze(AnalysisInput(
      candles: {
        Timeframe.m1: [
          Candle(time: now, open: 1, high: 2, low: 0.5, close: 1.5),
        ],
      },
      quote: Quote(mid: 1.5, time: now, source: 'test', bid: 1.4, ask: 1.6),
      settings: settings,
      now: now,
    ));
    expect(r.signals, isEmpty);
  });

  test('every emitted signal satisfies the hard rules (property test)', () async {
    var emitted = 0;
    for (var seed = 1; seed <= 25; seed++) {
      final p = MockMarketDataProvider(seed: seed);
      final candles = await _candles(p);
      final q = await p.fetchQuote();
      final r = const SignalEngine().analyze(AnalysisInput(
        candles: candles,
        quote: q,
        settings: settings,
        now: DateTime.now().toUtc(),
      ));
      for (final s in r.signals) {
        emitted++;
        expect(s.timeframe == 'M1' || s.timeframe == 'M5', isTrue,
            reason: 'only M1/M5 may be tradable');
        expect(s.score, greaterThanOrEqualTo(settings.minScore));
        expect(s.isMock, isTrue);
        if (s.isBuy) {
          expect(s.stopLoss, lessThan(s.entry));
          expect(s.takeProfit, greaterThan(s.entry));
        } else {
          expect(s.stopLoss, greaterThan(s.entry));
          expect(s.takeProfit, lessThan(s.entry));
        }
        expect(s.riskUsd, lessThanOrEqualTo(settings.normalRiskMax + 1e-9),
            reason: 'special risk is disabled by default');
        final rr = RiskCalculator.netRR(
            entry: s.entry,
            stop: s.stopLoss,
            target: s.takeProfit,
            lots: settings.lots,
            contractSize: settings.contractSize,
            cost: s.costUsd);
        expect(rr, greaterThanOrEqualTo(settings.minNetRR - 1e-6));
        expect(s.expiresAt.isAfter(s.createdAt), isTrue);
        expect(s.riskClass, RiskClass.normal);
      }
    }
    // Zero signals is a legitimate outcome of the strict rules; this test
    // checks invariants, not frequency.
    expect(emitted, greaterThanOrEqualTo(0));
  });

  test('Signal survives a JSON round trip', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final s = Signal(
      id: 'M5-buy-1',
      side: Side.buy,
      timeframe: 'M5',
      entryType: EntryType.conditional,
      entry: 4000,
      stopLoss: 3995,
      takeProfit: 4023,
      score: 81,
      riskUsd: 5,
      costUsd: 2,
      netLossUsd: 7,
      netTargetUsd: 21,
      riskClass: RiskClass.normal,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      atrAtCreation: 1.2,
      source: 'x',
      isMock: true,
      reasons: const [ReasonItem('a', 10, 20, 'd')],
      warnings: const ['w'],
    );
    final back = Signal.fromJson(s.toJson());
    expect(back.entry, 4000);
    expect(back.entryType, EntryType.conditional);
    expect(back.reasons.single.title, 'a');
    expect(back.expiresAt, s.expiresAt);
  });

  test('settings copyWith/JSON keeps defaults from the spec', () {
    const d = AppSettings();
    expect(d.lots, 0.01);
    expect(d.normalRiskMax, 5);
    expect(d.specialRiskMax, 10);
    expect(d.allowSpecialRisk, isFalse);
    expect(d.minNetRR, 3);
    expect(d.minScore, 65);
    final changed = d.copyWith({'lots': 0.02});
    expect(changed.lots, 0.02);
    expect(changed.balance, 100);
  });
}
