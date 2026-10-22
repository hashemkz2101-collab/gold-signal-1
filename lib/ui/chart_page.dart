import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/indicators/indicators.dart';
import '../core/models/signal.dart';
import '../core/models/timeframe.dart';
import 'candle_chart_painter.dart';
import 'format.dart';

class ChartPage extends ConsumerStatefulWidget {
  const ChartPage({super.key});

  @override
  ConsumerState<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends ConsumerState<ChartPage> {
  Timeframe _tf = Timeframe.m5;
  static const int _visible = 90;

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(marketProvider);
    final st = ref.watch(settingsProvider);
    final all = m.candles[_tf] ?? const [];

    Widget chart;
    if (all.length < 2) {
      chart = const Center(child: Text('داده‌ای برای نمایش نیست.'));
    } else {
      final closes = all.map((c) => c.close).toList();
      final e20 = ema(closes, st.emaFast);
      final e50 = ema(closes, st.emaMid);
      final from = math.max(0, all.length - _visible);
      Signal? sig;
      for (final s in m.activeSignals) {
        if (s.timeframe == _tf.label) {
          sig = s;
          break;
        }
      }
      // Zones from the same analysis run (M5 and higher).
      final levels = m.analysis?.levels ?? const [];
      chart = CustomPaint(
        size: Size.infinite,
        painter: CandleChartPainter(
          candles: all.sublist(from),
          levels: levels,
          ema20: e20.sublist(from),
          ema50: e50.sublist(from),
          price: m.quote?.mid,
          signal: sig,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<Timeframe>(
            segments: [
              for (final tf in Timeframe.values)
                ButtonSegment(value: tf, label: Text(tf.label)),
            ],
            selected: {_tf},
            onSelectionChanged: (s) => setState(() => _tf = s.first),
          ),
          const SizedBox(height: 8),
          Expanded(child: chart),
          const SizedBox(height: 6),
          Text(
            '${m.quote?.source ?? '—'}${m.quote?.isMock == true ? ' (آزمایشی)' : ''}'
            '${m.quote == null ? '' : ' — ${hms(m.quote!.time)}'}'
            ' | زرد: EMA${st.emaFast}  آبی: EMA${st.emaMid} | ناحیه‌ها: سبز تقاضا، قرمز عرضه، خاکستری سطح',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
