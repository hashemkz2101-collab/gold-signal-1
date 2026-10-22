import 'dart:math' as math;

import '../indicators/indicators.dart';
import '../models/app_settings.dart';
import '../models/candle.dart';
import '../models/quote.dart';
import '../models/signal.dart';
import '../models/timeframe.dart';
import '../risk/risk_calculator.dart';
import 'candle_patterns.dart';
import 'levels.dart';
import 'structure.dart';

class AnalysisInput {
  const AnalysisInput({
    required this.candles,
    required this.quote,
    required this.settings,
    required this.now,
    this.referencePrice,
  });

  /// CLOSED candles per timeframe, ascending by time.
  final Map<Timeframe, List<Candle>> candles;
  final Quote quote;
  final AppSettings settings;
  final DateTime now;

  /// Optional price the user reads from MT5, used to detect source mismatch.
  final double? referencePrice;
}

class Rejection {
  const Rejection(this.timeframe, this.side, this.reason);
  final Timeframe? timeframe;
  final Side? side;
  final String reason;
}

class TimeframeSummary {
  const TimeframeSummary({
    required this.timeframe,
    required this.structure,
    required this.lastClose,
    this.atr,
    this.rsi,
    this.emaFast,
    this.emaMid,
    this.emaSlow,
  });

  final Timeframe timeframe;
  final MarketStructure structure;
  final double lastClose;
  final double? atr;
  final double? rsi;
  final double? emaFast;
  final double? emaMid;
  final double? emaSlow;

  Trend get trend => structure.trend;
}

class AnalysisResult {
  const AnalysisResult({
    required this.signals,
    required this.rejections,
    required this.summaries,
    required this.levels,
    required this.warnings,
    required this.tradingAllowed,
    required this.spread,
    required this.spreadIsEstimated,
  });

  final List<Signal> signals;
  final List<Rejection> rejections;
  final Map<Timeframe, TimeframeSummary> summaries;
  final List<PriceLevel> levels;
  final List<String> warnings;

  /// False when data quality blocks any new signal.
  final bool tradingAllowed;
  final double spread;
  final bool spreadIsEstimated;
}

class _Tf {
  _Tf({
    required this.cs,
    required this.swings,
    required this.structure,
    required this.atrSeries,
    required this.rsiSeries,
    required this.ema20,
    required this.ema50,
    required this.ema200,
  });

  final List<Candle> cs;
  final List<Swing> swings;
  final MarketStructure structure;
  final List<double?> atrSeries;
  final List<double?> rsiSeries;
  final double? ema20;
  final double? ema50;
  final double? ema200;

  double get atr => lastValue(atrSeries) ?? 0;
}

class _Confirmation {
  const _Confirmation(this.points, this.label);
  final double points;
  final String label;
}

/// Explainable rule-based engine. It only uses CLOSED candles and swings that
/// are already confirmed, so it has no look-ahead. Nothing here places or
/// edits orders.
class SignalEngine {
  const SignalEngine();

  static const int minCandles = 60;

  AnalysisResult analyze(AnalysisInput input) {
    final st = input.settings;
    final warnings = <String>[];
    final rejections = <Rejection>[];
    var allowed = true;

    // ---- data quality gates -------------------------------------------
    final age = input.quote.age(input.now);
    if (age.inSeconds > st.maxDataAgeSeconds) {
      allowed = false;
      warnings.add('داده قدیمی است (${age.inSeconds} ثانیه)؛ سیگنال جدید صادر نمی‌شود.');
    }
    final ref = input.referencePrice;
    if (ref != null) {
      final diff = (input.quote.mid - ref).abs();
      if (diff > st.maxPriceDiff) {
        allowed = false;
        warnings.add(
            'اختلاف قیمت منبع با قیمت MT5 (${diff.toStringAsFixed(2)}) از حد مجاز بیشتر است؛ صدور سیگنال متوقف شد.');
      }
    }
    final realSpread = input.quote.spread;
    final spreadEstimated = realSpread == null;
    final spread = realSpread ?? st.estimatedSpread;
    if (spread > st.maxSpread) {
      allowed = false;
      warnings.add(
          'اسپرد ${spread.toStringAsFixed(2)} از حداکثر مجاز ${st.maxSpread.toStringAsFixed(2)} بیشتر است.');
    }
    if (spreadEstimated) {
      warnings.add('منبع داده Bid/Ask ندارد؛ اسپرد تخمینی کاربر استفاده شد.');
    }
    if (input.quote.isMock) {
      warnings.add('داده آزمایشی (ساختگی) است؛ قیمت واقعی بازار نیست.');
    }

    // ---- per-timeframe computation ------------------------------------
    final data = <Timeframe, _Tf>{};
    final summaries = <Timeframe, TimeframeSummary>{};
    for (final tf in Timeframe.values) {
      final cs = input.candles[tf];
      if (cs == null || cs.length < minCandles) {
        if (tf.isTradable) {
          warnings.add('کندل ${tf.label} کافی نیست.');
        }
        continue;
      }
      final d = _compute(cs, st);
      data[tf] = d;
      summaries[tf] = TimeframeSummary(
        timeframe: tf,
        structure: d.structure,
        lastClose: cs.last.close,
        atr: lastValue(d.atrSeries),
        rsi: lastValue(d.rsiSeries),
        emaFast: d.ema20,
        emaMid: d.ema50,
        emaSlow: d.ema200,
      );
    }

    // ---- levels ---------------------------------------------------------
    final levels = <PriceLevel>[];
    for (final tf in [Timeframe.m5, Timeframe.m15, Timeframe.m30, Timeframe.h1]) {
      final d = data[tf];
      if (d == null || d.atr <= 0) continue;
      levels.addAll(detectSwingLevels(tf, d.cs, d.swings, d.atr));
      levels.addAll(detectSupplyDemand(tf, d.cs, d.atr));
    }

    // ---- signals ----------------------------------------------------------
    final signals = <Signal>[];
    if (!allowed) {
      rejections.add(const Rejection(null, null, 'صدور سیگنال به‌دلیل کیفیت داده/هزینه متوقف است.'));
    } else {
      for (final tf in [Timeframe.m5, Timeframe.m1]) {
        Signal? best;
        for (final side in Side.values) {
          final s = _evaluate(
              tf, side, data, levels, input, spread, spreadEstimated, rejections);
          if (s != null && (best == null || s.score > best.score)) best = s;
        }
        if (best != null) signals.add(best);
      }
    }

    return AnalysisResult(
      signals: signals,
      rejections: rejections,
      summaries: summaries,
      levels: levels,
      warnings: warnings,
      tradingAllowed: allowed,
      spread: spread,
      spreadIsEstimated: spreadEstimated,
    );
  }

  _Tf _compute(List<Candle> cs, AppSettings st) {
    final closes = cs.map((c) => c.close).toList();
    final swings = detectSwings(cs, n: st.swingStrength);
    return _Tf(
      cs: cs,
      swings: swings,
      structure: analyzeStructure(cs, swings),
      atrSeries: atr(cs, st.atrPeriod),
      rsiSeries: rsi(closes, st.rsiPeriod),
      ema20: lastValue(ema(closes, st.emaFast)),
      ema50: lastValue(ema(closes, st.emaMid)),
      // EMA200 is shown but never used as a hard filter (see spec 6.6).
      ema200: lastValue(ema(closes, st.emaSlow)),
    );
  }

  Signal? _evaluate(
    Timeframe tf,
    Side side,
    Map<Timeframe, _Tf> data,
    List<PriceLevel> levels,
    AnalysisInput input,
    double spread,
    bool spreadEstimated,
    List<Rejection> rej,
  ) {
    final st = input.settings;
    final d = data[tf];
    void reject(String why) => rej.add(Rejection(tf, side, why));
    if (d == null || d.atr <= 0) {
      reject('داده کافی برای تحلیل نیست.');
      return null;
    }
    final isBuy = side == Side.buy;
    final atrV = d.atr;
    final cs = d.cs;
    final last = cs.last;
    final mid = input.quote.mid;

    // ---- volatility / liquidity gates ----------------------------------
    if (last.range > 3 * atrV) {
      reject('کندل آخر بسیار بزرگ است (بیش از ۳ برابر ATR).');
      return null;
    }
    final atrVals = d.atrSeries.whereType<double>().toList();
    final tail = atrVals.length > 50 ? atrVals.sublist(atrVals.length - 50) : atrVals;
    final atrMed = median(tail);
    if (atrMed > 0 && atrV > 2.5 * atrMed) {
      reject('نوسان غیرعادی (ATR بیش از ۲٫۵ برابر میانه).');
      return null;
    }

    // ---- higher timeframe context ------------------------------------
    final want = isBuy ? Trend.up : Trend.down;
    final opp = isBuy ? Trend.down : Trend.up;
    final h1 = data[Timeframe.h1]?.structure.trend ?? Trend.range;
    final m30 = data[Timeframe.m30]?.structure.trend ?? Trend.range;
    final m15 = data[Timeframe.m15]?.structure.trend ?? Trend.range;
    double align(Trend t) => t == want ? 1.0 : (t == Trend.range ? 0.4 : 0.0);
    if (h1 == opp && m30 == opp) {
      reject('تضاد شدید با جهت H1 و M30.');
      return null;
    }

    // ---- 1) structure (20) ---------------------------------------------
    final structurePts = 20 * (0.6 * align(d.structure.trend) + 0.4 * align(h1));

    // ---- 5) timeframe alignment (15) -----------------------------------
    double a5(Trend t) => t == want ? 5 : (t == Trend.range ? 2 : 0);
    final alignPts = a5(m15) + a5(m30) + a5(h1);

    // ---- 2) level quality (20) -----------------------------------------
    PriceLevel? zone;
    for (final l in levels) {
      final typeOk = isBuy ? l.type != LevelType.supply : l.type != LevelType.demand;
      if (!typeOk) continue;
      final near = isBuy
          ? (mid >= l.low - 0.3 * atrV && mid <= l.high + 1.0 * atrV)
          : (mid <= l.high + 0.3 * atrV && mid >= l.low - 1.0 * atrV);
      if (!near) continue;
      if (zone == null ||
          l.strength > zone.strength ||
          (l.strength == zone.strength &&
              l.distanceFrom(mid) < zone.distanceFrom(mid))) {
        zone = l;
      }
    }
    final levelPts = zone == null ? 0.0 : 20 * (0.4 + 0.6 * zone.strength);

    // ---- 3) confirmation (20) ------------------------------------------
    final conf = _confirmation(isBuy, cs, zone, d.structure, atrV);

    // ---- 4) candle + momentum (15) -------------------------------------
    final patterns = detectPatterns(cs, atrV);
    final dirPatterns = isBuy ? bullishPatterns : bearishPatterns;
    final hasDirPattern = patterns.any(dirPatterns.contains);
    final patPts = hasDirPattern ? 8.0 : (patterns.contains(CandlePattern.insideBar) ? 2.0 : 0.0);

    final rsiNow = lastValue(d.rsiSeries);
    double prevRsi = rsiNow ?? 50;
    for (var i = d.rsiSeries.length - 2; i >= 0; i--) {
      final v = d.rsiSeries[i];
      if (v != null) {
        prevRsi = v;
        break;
      }
    }
    var rsiPts = 2.0;
    String rsiNote = 'RSI خنثی';
    final warn = <String>[];
    if (rsiNow != null) {
      if (isBuy) {
        if (rsiNow > 70) {
          rsiPts = 0;
          rsiNote = 'RSI در اشباع خرید (${rsiNow.toStringAsFixed(0)})';
          warn.add('RSI در ناحیه اشباع خرید است.');
        } else if (rsiNow >= 40 && rsiNow > prevRsi) {
          rsiPts = 4;
          rsiNote = 'مومنتوم صعودی (RSI ${rsiNow.toStringAsFixed(0)})';
        }
      } else {
        if (rsiNow < 30) {
          rsiPts = 0;
          rsiNote = 'RSI در اشباع فروش (${rsiNow.toStringAsFixed(0)})';
          warn.add('RSI در ناحیه اشباع فروش است.');
        } else if (rsiNow <= 60 && rsiNow < prevRsi) {
          rsiPts = 4;
          rsiNote = 'مومنتوم نزولی (RSI ${rsiNow.toStringAsFixed(0)})';
        }
      }
    }
    var emaPts = 0.0;
    final e20 = d.ema20, e50 = d.ema50;
    if (e20 != null && e50 != null) {
      if (isBuy) {
        emaPts = (last.close > e20 && e20 > e50) ? 3 : (last.close > e50 ? 1 : 0);
      } else {
        emaPts = (last.close < e20 && e20 < e50) ? 3 : (last.close < e50 ? 1 : 0);
      }
    }
    final candleMomentumPts = patPts + rsiPts + emaPts;

    // ---- 6) entry quality (10) -----------------------------------------
    final spreadRatio = spread / atrV;
    final spreadPts = spreadRatio <= 0.1 ? 5.0 : spreadRatio <= 0.2 ? 3.0 : spreadRatio <= 0.35 ? 1.0 : 0.0;
    final volRatio = atrMed > 0 ? atrV / atrMed : 1.0;
    final volPts = (volRatio >= 0.5 && volRatio <= 1.8) ? 5.0 : 2.0;
    final qualityPts = spreadPts + volPts;

    final total = structurePts + levelPts + conf.points + candleMomentumPts + alignPts + qualityPts;
    if (total < st.minScore) {
      reject('امتیاز ${total.toStringAsFixed(0)} کمتر از حداقل ${st.minScore} است.');
      return null;
    }

    // ---- entry, stop, target -------------------------------------------
    final halfSpread = spread / 2;
    final exec = isBuy
        ? (input.quote.ask ?? mid + halfSpread)
        : (input.quote.bid ?? mid - halfSpread);

    final anchor = isBuy
        ? (zone?.low ?? d.structure.lastLow?.price)
        : (zone?.high ?? d.structure.lastHigh?.price);
    if (anchor == null) {
      reject('حد ضرر تکنیکال معتبر پیدا نشد.');
      return null;
    }

    final immediate = conf.points >= 14;
    double entry = exec;
    if (!immediate && zone != null) {
      // Conditional alert: wait for price to come to the zone edge.
      entry = isBuy ? math.min(exec, zone.high) : math.max(exec, zone.low);
    }

    double stop;
    if (isBuy) {
      final base = immediate ? math.min(anchor, last.low) : anchor;
      stop = base - 0.25 * atrV;
    } else {
      final base = immediate ? math.max(anchor, last.high) : anchor;
      stop = base + 0.25 * atrV;
    }
    if (isBuy ? stop >= entry : stop <= entry) {
      reject('حد ضرر در سمت درست ورود قرار نمی‌گیرد.');
      return null;
    }
    final stopDist = (entry - stop).abs();
    if (stopDist < st.minStopAtr * atrV) {
      reject('حد ضرر تکنیکال از ${st.minStopAtr} ATR کوچک‌تر است (برای جا شدن در ریسک جابه‌جا نمی‌شود).');
      return null;
    }

    final risk = RiskCalculator.priceRisk(
        entry: entry, stop: stop, lots: st.lots, contractSize: st.contractSize);
    final rc = RiskCalculator.classify(
      priceRisk: risk,
      normalMax: st.normalRiskMax,
      specialMax: st.specialRiskMax,
      allowSpecial: st.allowSpecialRisk,
    );
    if (rc == null) {
      reject('ریسک قیمتی ${risk.toStringAsFixed(2)} دلار از سقف مجاز بیشتر است (حجم تغییر نمی‌کند).');
      return null;
    }

    final cost = spread * RiskCalculator.usdPerDollarMove(st.lots, st.contractSize) +
        st.commissionRoundTrip;
    final target = RiskCalculator.targetPrice(
      side: side,
      entry: entry,
      priceRisk: risk,
      cost: cost,
      lots: st.lots,
      contractSize: st.contractSize,
      rr: st.minNetRR,
    );

    // Obstacle between entry and target.
    for (final l in levels) {
      if (l.strength < 0.45) continue;
      final blocks = isBuy
          ? (l.type != LevelType.demand && l.low > entry && l.low < target)
          : (l.type != LevelType.supply && l.high < entry && l.high > target);
      if (blocks) {
        reject('سطح مهم ${l.low.toStringAsFixed(2)}–${l.high.toStringAsFixed(2)} (${l.timeframe.label}) قبل از حد سود قرار دارد.');
        return null;
      }
    }

    final netRR = RiskCalculator.netRR(
        entry: entry,
        stop: stop,
        target: target,
        lots: st.lots,
        contractSize: st.contractSize,
        cost: cost);
    if (netRR < st.minNetRR - 1e-6) {
      reject('نسبت سود به زیان خالص ${netRR.toStringAsFixed(2)} کمتر از حداقل است.');
      return null;
    }

    final reasons = <ReasonItem>[
      ReasonItem('ساختار بازار و روند', structurePts, 20,
          '${tf.label}: ${_trendFa(d.structure.trend)}، H1: ${_trendFa(h1)}'),
      ReasonItem('کیفیت ناحیه', levelPts, 20,
          zone == null
              ? 'ناحیه معتبر نزدیک پیدا نشد'
              : 'ناحیه ${zone.low.toStringAsFixed(2)}–${zone.high.toStringAsFixed(2)} از ${zone.timeframe.label}، ${zone.touches} برخورد'),
      ReasonItem('تأیید شکست/پولبک/واکنش', conf.points, 20, conf.label),
      ReasonItem('تأیید کندلی و مومنتوم', candleMomentumPts, 15,
          '${hasDirPattern ? 'الگوی کندلی هم‌جهت' : 'بدون الگوی کندلی هم‌جهت'}؛ $rsiNote'),
      ReasonItem('هماهنگی تایم‌فریم‌ها', alignPts, 15,
          'M15: ${_trendFa(m15)}، M30: ${_trendFa(m30)}، H1: ${_trendFa(h1)}'),
      ReasonItem('کیفیت ورود و نوسان', qualityPts, 10,
          'اسپرد/ATR = ${spreadRatio.toStringAsFixed(2)}${spreadEstimated ? ' (اسپرد تخمینی)' : ''}'),
    ];

    final warnings = <String>[
      ...warn,
      if (rc == RiskClass.high)
        'ریسک بالا: با موجودی ${st.balance.toStringAsFixed(0)} دلار چند زیان متوالی بخش بزرگی از موجودی را از بین می‌برد.',
      if (!immediate)
        'ورود مشروط است؛ فقط وقتی قیمت به ${entry.toStringAsFixed(2)} رسید در نظر بگیرید. برنامه سفارشی ثبت نمی‌کند.',
      if (input.quote.isMock) 'سیگنال آزمایشی بر پایه داده ساختگی است.',
      'اخبار اقتصادی بررسی نشده است.',
    ];

    final expiryMin = tf == Timeframe.m1 ? st.m1ExpiryMinutes : st.m5ExpiryMinutes;
    final now = input.now.toUtc();
    return Signal(
      id: '${tf.label}-${side.name}-${now.millisecondsSinceEpoch}',
      side: side,
      timeframe: tf.label,
      entryType: immediate ? EntryType.immediate : EntryType.conditional,
      entry: entry,
      stopLoss: stop,
      takeProfit: target,
      score: total,
      riskUsd: risk,
      costUsd: cost,
      netLossUsd: RiskCalculator.netLoss(risk, cost),
      netTargetUsd: RiskCalculator.netTarget(risk, cost, rr: st.minNetRR),
      riskClass: rc,
      createdAt: now,
      expiresAt: now.add(Duration(minutes: expiryMin)),
      atrAtCreation: atrV,
      source: input.quote.source,
      isMock: input.quote.isMock,
      reasons: reasons,
      warnings: warnings,
    );
  }

  _Confirmation _confirmation(bool isBuy, List<Candle> cs, PriceLevel? zone,
      MarketStructure s, double atrV) {
    final last = cs.last;
    if (zone != null) {
      // Rejection from the zone.
      final rejected = isBuy
          ? (last.low <= zone.high && last.close > zone.high && last.isBullish)
          : (last.high >= zone.low && last.close < zone.low && last.isBearish);
      if (rejected) return const _Confirmation(20, 'رد قیمت از ناحیه با کندل هم‌جهت');

      // Break + retest hold.
      final n = cs.length;
      final from = math.max(0, n - 40);
      int? j;
      for (var i = from; i < n - 1; i++) {
        if (isBuy ? cs[i].close < zone.low : cs[i].close > zone.high) j = i;
      }
      if (j != null) {
        var broke = false;
        for (var i = j + 1; i < n - 1; i++) {
          if (isBuy ? cs[i].close > zone.high : cs[i].close < zone.low) {
            broke = true;
            break;
          }
        }
        if (broke) {
          final held = isBuy
              ? (last.low <= zone.high + 0.2 * atrV && last.close > zone.high)
              : (last.high >= zone.low - 0.2 * atrV && last.close < zone.low);
          if (held) return const _Confirmation(18, 'شکست ناحیه، پولبک و حفظ سطح');
        }
      }
    }
    if (isBuy ? s.hasBreakUp : s.hasBreakDown) {
      return const _Confirmation(8, 'شکست ساختار (BOS/CHoCH) بدون پولبک تأییدشده');
    }
    return const _Confirmation(0, 'تأیید شکست/پولبک/واکنش وجود ندارد');
  }

  String _trendFa(Trend t) {
    switch (t) {
      case Trend.up:
        return 'صعودی';
      case Trend.down:
        return 'نزولی';
      case Trend.range:
        return 'رنج';
    }
  }
}
