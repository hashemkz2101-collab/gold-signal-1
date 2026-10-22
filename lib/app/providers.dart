import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analysis/signal_engine.dart';
import '../core/analysis/signal_validator.dart';
import '../core/models/app_settings.dart';
import '../core/models/candle.dart';
import '../core/models/quote.dart';
import '../core/models/signal.dart';
import '../core/models/timeframe.dart';
import '../data/market_data_provider.dart';
import '../data/mock_provider.dart';
import '../data/notification_service.dart';
import '../data/storage.dart';

// ---------------------------------------------------------------- settings

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repo) : super(const AppSettings()) {
    _load();
  }

  final SettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.load();
  }

  Future<void> update(Map<String, Object?> changes) async {
    state = state.copyWith(changes);
    try {
      await _repo.save(state);
    } catch (_) {}
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
    (ref) => SettingsNotifier(SettingsRepository()));

// ------------------------------------------------------------------ market

class MarketState {
  const MarketState({
    this.quote,
    this.candles = const {},
    this.connection = ConnectionStatus.connecting,
    this.error,
    this.analysis,
    this.signals = const [],
    this.lastUpdate,
    this.referencePrice,
  });

  final Quote? quote;
  final Map<Timeframe, List<Candle>> candles;
  final ConnectionStatus connection;
  final String? error;
  final AnalysisResult? analysis;
  final List<Signal> signals;
  final DateTime? lastUpdate;
  final double? referencePrice;

  List<Signal> get activeSignals => signals.where((s) => s.isActive).toList();

  MarketState copyWith({
    Quote? quote,
    Map<Timeframe, List<Candle>>? candles,
    ConnectionStatus? connection,
    String? error,
    bool clearError = false,
    AnalysisResult? analysis,
    List<Signal>? signals,
    DateTime? lastUpdate,
    double? referencePrice,
    bool clearReference = false,
  }) =>
      MarketState(
        quote: quote ?? this.quote,
        candles: candles ?? this.candles,
        connection: connection ?? this.connection,
        error: clearError ? null : (error ?? this.error),
        analysis: analysis ?? this.analysis,
        signals: signals ?? this.signals,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        referencePrice:
            clearReference ? null : (referencePrice ?? this.referencePrice),
      );
}

class MarketController extends StateNotifier<MarketState> {
  MarketController(this._ref) : super(const MarketState());

  final Ref _ref;
  final _engine = const SignalEngine();
  final _signalRepo = SignalRepository();
  final _notifier = NotificationService();
  final _mock = MockMarketDataProvider();

  Timer? _timer;
  bool _busy = false;
  DateTime? _lastCandleFetch;

  Future<void> start() async {
    await _notifier.init();
    try {
      final saved = await _signalRepo.recent();
      state = state.copyWith(signals: saved);
    } catch (_) {}
    await _tick();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _tick());
  }

  void setReferencePrice(double? value) {
    state = value == null
        ? state.copyWith(clearReference: true)
        : state.copyWith(referencePrice: value);
  }

  MarketDataProvider _provider(AppSettings st) =>
      st.useMock ? _mock : const UnconfiguredProvider();

  Future<void> _tick() async {
    if (_busy) return;
    _busy = true;
    final st = _ref.read(settingsProvider);
    final provider = _provider(st);
    try {
      final quote = await provider.fetchQuote();
      final now = DateTime.now().toUtc();

      var candles = state.candles;
      final needCandles = candles.isEmpty ||
          _lastCandleFetch == null ||
          now.difference(_lastCandleFetch!).inSeconds >= 20;
      if (needCandles) {
        final fresh = <Timeframe, List<Candle>>{};
        for (final tf in Timeframe.values) {
          fresh[tf] = await provider.fetchCandles(tf, count: 300);
        }
        candles = fresh;
        _lastCandleFetch = now;
      }

      final result = _engine.analyze(AnalysisInput(
        candles: candles,
        quote: quote,
        settings: st,
        now: now,
        referencePrice: state.referencePrice,
      ));

      var signals = List<Signal>.of(state.signals);
      await _revalidate(signals, quote, now, st, result);
      signals = List<Signal>.of(state.signals); // refreshed by _revalidate

      for (final s in result.signals) {
        final dup = signals.any((e) =>
            e.isActive && e.timeframe == s.timeframe && e.side == s.side);
        if (dup) continue;
        signals.insert(0, s);
        await _persist(s);
        await _notify(st, s);
      }
      if (signals.length > 200) signals = signals.sublist(0, 200);

      state = state.copyWith(
        quote: quote,
        candles: candles,
        connection: ConnectionStatus.connected,
        clearError: true,
        analysis: result,
        signals: signals,
        lastUpdate: now,
      );
    } catch (e) {
      state = state.copyWith(
          connection: ConnectionStatus.error, error: e.toString());
    } finally {
      _busy = false;
    }
  }

  Future<void> _revalidate(List<Signal> signals, Quote quote, DateTime now,
      AppSettings st, AnalysisResult result) async {
    final updated = <Signal>[];
    for (final s in signals) {
      if (!s.isActive) {
        updated.add(s);
        continue;
      }
      final tf = s.timeframe == 'M1' ? Timeframe.m1 : Timeframe.m5;
      final structure = result.summaries[tf]?.structure;
      final check = SignalValidator.check(s,
          quote: quote, now: now, settings: st, structure: structure);
      if (check == null) {
        updated.add(s);
        continue;
      }
      final next = s.copyWith(status: check.status, statusReason: check.reason);
      updated.add(next);
      await _persist(next);
      final label = check.status == SignalStatus.expired ? 'منقضی شد' : 'لغو شد';
      await _notify(st, next,
          title: 'سیگنال ${s.timeframe} ${s.isBuy ? 'خرید' : 'فروش'} $label',
          body: check.reason);
    }
    state = state.copyWith(signals: updated);
  }

  Future<void> _persist(Signal s) async {
    try {
      await _signalRepo.upsert(s);
    } catch (_) {}
  }

  Future<void> _notify(AppSettings st, Signal s,
      {String? title, String? body}) async {
    if (!st.notificationsEnabled) return;
    final prefix = s.isMock ? '[آزمایشی] ' : '';
    final t = title ??
        '$prefix${s.isBuy ? 'خرید' : 'فروش'} ${st.symbol} ${s.timeframe} — امتیاز ${s.score.toStringAsFixed(0)}';
    final b = body ??
        '${s.entryType == EntryType.immediate ? 'ورود' : 'ورود مشروط'} ${s.entry.toStringAsFixed(2)} | '
            'SL ${s.stopLoss.toStringAsFixed(2)} | TP ${s.takeProfit.toStringAsFixed(2)}';
    await _notifier.show(s.id.hashCode & 0x7fffffff, t, b);
  }

  Future<void> clearHistory() async {
    try {
      await _signalRepo.clear();
    } catch (_) {}
    state = state.copyWith(signals: const []);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final marketProvider = StateNotifierProvider<MarketController, MarketState>(
    (ref) => MarketController(ref)..start());
