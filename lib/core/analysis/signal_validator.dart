import '../models/app_settings.dart';
import '../models/quote.dart';
import '../models/signal.dart';
import '../risk/risk_calculator.dart';
import 'structure.dart';

class SignalCheck {
  const SignalCheck(this.status, this.reason);
  final SignalStatus status;
  final String reason;
}

/// Decides whether an active signal must be cancelled. Returns null if the
/// signal is still valid.
class SignalValidator {
  const SignalValidator._();

  /// Small allowance on the net R:R re-check so that one tick of normal
  /// spread movement does not cancel a fresh signal. The engine itself still
  /// requires the full minimum when it creates a signal.
  static const double rrTolerance = 0.1;

  static SignalCheck? check(
    Signal s, {
    required Quote quote,
    required DateTime now,
    required AppSettings settings,
    MarketStructure? structure,
  }) {
    if (!s.isActive) return null;
    final t = now.toUtc();
    if (!t.isBefore(s.expiresAt)) {
      return const SignalCheck(SignalStatus.expired, 'زمان اعتبار سیگنال تمام شد.');
    }
    if (quote.age(now).inSeconds > settings.maxDataAgeSeconds) {
      return const SignalCheck(SignalStatus.invalidated, 'داده قیمت قدیمی شد.');
    }

    // Prices at which the user would EXIT: buy exits at bid, sell at ask.
    final exitPrice = s.isBuy ? (quote.bid ?? quote.mid) : (quote.ask ?? quote.mid);
    final stopHit = s.isBuy ? exitPrice <= s.stopLoss : exitPrice >= s.stopLoss;
    if (stopHit) {
      return const SignalCheck(SignalStatus.invalidated, 'قیمت به حد ضرر رسید.');
    }
    final targetHit = s.isBuy ? quote.mid >= s.takeProfit : quote.mid <= s.takeProfit;
    if (targetHit) {
      return const SignalCheck(SignalStatus.invalidated, 'قیمت پیش از ورود به حد سود رسید.');
    }

    if (s.entryType == EntryType.immediate) {
      final exec = s.isBuy ? (quote.ask ?? quote.mid) : (quote.bid ?? quote.mid);
      final chase = s.isBuy ? exec - s.entry : s.entry - exec;
      if (chase > 0.5 * s.atrAtCreation) {
        return const SignalCheck(
            SignalStatus.invalidated, 'قیمت از نقطه ورود فاصله گرفت؛ ورود دیگر منطقی نیست.');
      }
      final rr = RiskCalculator.netRR(
        entry: exec,
        stop: s.stopLoss,
        target: s.takeProfit,
        lots: settings.lots,
        contractSize: settings.contractSize,
        cost: s.costUsd,
      );
      if (rr < settings.minNetRR - rrTolerance) {
        return const SignalCheck(
            SignalStatus.invalidated, 'نسبت سود به زیان خالص زیر حداقل مجاز رسید.');
      }
    }

    if (structure != null) {
      final broken = s.isBuy ? structure.hasBreakDown : structure.hasBreakUp;
      if (broken) {
        return const SignalCheck(SignalStatus.invalidated, 'ساختار بازار برخلاف سیگنال تغییر کرد.');
      }
    }
    return null;
  }
}
