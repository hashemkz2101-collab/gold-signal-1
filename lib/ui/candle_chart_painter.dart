import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/analysis/levels.dart';
import '../core/models/candle.dart';
import '../core/models/signal.dart';

class CandleChartPainter extends CustomPainter {
  CandleChartPainter({
    required this.candles,
    required this.levels,
    required this.ema20,
    required this.ema50,
    this.price,
    this.signal,
  });

  /// Visible candles. [ema20]/[ema50] must be aligned with [candles].
  final List<Candle> candles;
  final List<PriceLevel> levels;
  final List<double?> ema20;
  final List<double?> ema50;
  final double? price;
  final Signal? signal;

  static const double _rightPad = 58;

  void _label(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final w = size.width - _rightPad;
    final h = size.height;

    var lo = candles.map((c) => c.low).reduce(math.min);
    var hi = candles.map((c) => c.high).reduce(math.max);
    final s = signal;
    if (s != null && s.isActive) {
      lo = math.min(lo, math.min(s.stopLoss, s.takeProfit));
      hi = math.max(hi, math.max(s.stopLoss, s.takeProfit));
    }
    final pad = (hi - lo) * 0.05 + 1e-9;
    lo -= pad;
    hi += pad;
    double y(double p) => h - (p - lo) / (hi - lo) * h;

    final cw = w / candles.length;

    // Zones
    for (final l in levels) {
      if (l.high < lo || l.low > hi) continue;
      final color = l.type == LevelType.demand
          ? Colors.green
          : l.type == LevelType.supply
              ? Colors.red
              : Colors.blueGrey;
      canvas.drawRect(
        Rect.fromLTRB(0, y(l.high), w, y(l.low)),
        Paint()..color = color.withValues(alpha: 0.12 + 0.2 * l.strength),
      );
    }

    // Candles
    final wick = Paint()..strokeWidth = 1;
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = i * cw + cw / 2;
      final up = c.close >= c.open;
      final col = up ? Colors.green : Colors.red;
      wick.color = col;
      canvas.drawLine(Offset(x, y(c.high)), Offset(x, y(c.low)), wick);
      final top = y(math.max(c.open, c.close));
      var bottom = y(math.min(c.open, c.close));
      if (bottom - top < 1) bottom = top + 1;
      canvas.drawRect(
        Rect.fromLTRB(x - cw * 0.35, top, x + cw * 0.35, bottom),
        Paint()..color = col,
      );
    }

    // EMAs
    void drawLine(List<double?> v, Color color) {
      final path = Path();
      var started = false;
      for (var i = 0; i < v.length && i < candles.length; i++) {
        final val = v[i];
        if (val == null) continue;
        final p = Offset(i * cw + cw / 2, y(val));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    drawLine(ema20, Colors.amber);
    drawLine(ema50, Colors.lightBlueAccent);

    void hLine(double p, Color color, String label, {bool dashed = false}) {
      if (p < lo || p > hi) return;
      final yy = y(p);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1;
      if (dashed) {
        for (double x = 0; x < w; x += 8) {
          canvas.drawLine(Offset(x, yy), Offset(math.min(x + 4, w), yy), paint);
        }
      } else {
        canvas.drawLine(Offset(0, yy), Offset(w, yy), paint);
      }
      _label(canvas, '$label ${p.toStringAsFixed(2)}', Offset(w + 2, yy - 6), color);
    }

    if (price != null) hLine(price!, Colors.white70, '', dashed: true);
    if (s != null && s.isActive) {
      hLine(s.entry, Colors.white, 'E');
      hLine(s.stopLoss, Colors.redAccent, 'SL');
      hLine(s.takeProfit, Colors.greenAccent, 'TP');
    }
  }

  @override
  bool shouldRepaint(covariant CandleChartPainter old) => true;
}
