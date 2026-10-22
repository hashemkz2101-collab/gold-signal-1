import 'package:flutter_test/flutter_test.dart';
import 'package:gold_signal_assistant/core/analysis/signal_validator.dart';
import 'package:gold_signal_assistant/core/models/app_settings.dart';
import 'package:gold_signal_assistant/core/models/quote.dart';
import 'package:gold_signal_assistant/core/models/signal.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

Signal _signal({
  Side side = Side.buy,
  EntryType type = EntryType.immediate,
  double entry = 4000,
  double sl = 3995,
  double tp = 4023,
}) =>
    Signal(
      id: 'x',
      side: side,
      timeframe: 'M5',
      entryType: type,
      entry: entry,
      stopLoss: sl,
      takeProfit: tp,
      score: 80,
      riskUsd: 5,
      costUsd: 2,
      netLossUsd: 7,
      netTargetUsd: 21,
      riskClass: RiskClass.normal,
      createdAt: _t0,
      expiresAt: _t0.add(const Duration(minutes: 30)),
      atrAtCreation: 2.0,
      source: 'test',
      isMock: false,
      reasons: const [],
    );

Quote _q(double mid, DateTime t, {double? bid, double? ask}) =>
    Quote(mid: mid, bid: bid, ask: ask, time: t, source: 'test');

void main() {
  const st = AppSettings();

  test('valid signal stays active', () {
    final now = _t0.add(const Duration(minutes: 1));
    final r = SignalValidator.check(_signal(),
        quote: _q(4000, now, bid: 3999.9, ask: 4000.1), now: now, settings: st);
    expect(r, isNull);
  });

  test('expires after its validity window', () {
    final now = _t0.add(const Duration(minutes: 31));
    final r = SignalValidator.check(_signal(),
        quote: _q(4000, now), now: now, settings: st);
    expect(r?.status, SignalStatus.expired);
  });

  test('stale data invalidates', () {
    final now = _t0.add(const Duration(minutes: 5));
    final r = SignalValidator.check(_signal(),
        quote: _q(4000, now.subtract(const Duration(minutes: 3))),
        now: now,
        settings: st);
    expect(r?.status, SignalStatus.invalidated);
  });

  test('buy: price reaching the stop invalidates', () {
    final now = _t0.add(const Duration(minutes: 2));
    final r = SignalValidator.check(_signal(),
        quote: _q(3994.9, now), now: now, settings: st);
    expect(r?.status, SignalStatus.invalidated);
  });

  test('sell: price reaching the stop invalidates', () {
    final now = _t0.add(const Duration(minutes: 2));
    final r = SignalValidator.check(
        _signal(side: Side.sell, entry: 4000, sl: 4005, tp: 3977),
        quote: _q(4005.1, now),
        now: now,
        settings: st);
    expect(r?.status, SignalStatus.invalidated);
  });

  test('immediate buy: price running away from entry invalidates', () {
    final now = _t0.add(const Duration(minutes: 2));
    // atr 2.0 -> max chase 1.0
    final r = SignalValidator.check(_signal(),
        quote: _q(4001.5, now), now: now, settings: st);
    expect(r?.status, SignalStatus.invalidated);
  });

  test('conditional signal is not killed by price being away from entry', () {
    final now = _t0.add(const Duration(minutes: 2));
    final r = SignalValidator.check(_signal(type: EntryType.conditional),
        quote: _q(4001.5, now), now: now, settings: st);
    expect(r, isNull);
  });

  test('inactive signals are ignored', () {
    final now = _t0.add(const Duration(minutes: 99));
    final r = SignalValidator.check(
        _signal().copyWith(status: SignalStatus.expired),
        quote: _q(1, now),
        now: now,
        settings: st);
    expect(r, isNull);
  });
}
