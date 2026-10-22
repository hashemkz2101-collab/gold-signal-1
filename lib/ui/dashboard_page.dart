import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/analysis/structure.dart';
import '../core/models/quote.dart';
import '../core/models/timeframe.dart';
import 'format.dart';
import 'signal_card.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _refCtrl = TextEditingController();

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  String _trendFa(Trend t) =>
      t == Trend.up ? 'صعودی' : (t == Trend.down ? 'نزولی' : 'رنج');

  Color _trendColor(Trend t) =>
      t == Trend.up ? Colors.green : (t == Trend.down ? Colors.red : Colors.grey);

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(marketProvider);
    final settings = ref.watch(settingsProvider);
    final q = m.quote;
    final analysis = m.analysis;
    final theme = Theme.of(context);

    final connText = {
      ConnectionStatus.connecting: 'در حال اتصال…',
      ConnectionStatus.connected: 'متصل',
      ConnectionStatus.error: 'خطا',
    }[m.connection]!;
    final ageSec = q?.age(DateTime.now()).inSeconds;
    final stale = ageSec != null && ageSec > settings.maxDataAgeSeconds;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          child: const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'این برنامه فقط ابزار تحلیل کمکی است؛ سیگنال تضمین سود نیست و هیچ معامله‌ای را خودکار انجام نمی‌دهد. تصمیم و اجرای معامله با خود شماست.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(settings.symbol, style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Chip(label: Text(connText)),
                ]),
                Text(q == null ? '—' : fmt(q.mid),
                    style: theme.textTheme.displaySmall),
                if (q != null) ...[
                  Text(q.hasRealBidAsk
                      ? 'Bid ${fmt(q.bid!)}   Ask ${fmt(q.ask!)}'
                      : 'فقط قیمت مرجع (Bid/Ask واقعی ندارد)'),
                  Text(analysis == null
                      ? 'اسپرد: —'
                      : 'اسپرد: ${fmt(analysis.spread)}${analysis.spreadIsEstimated ? ' (تخمینی)' : ''}'),
                  Row(children: [
                    Text('منبع: ${q.source}'),
                    if (q.isMock)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 8),
                        child: Chip(label: Text('داده آزمایشی — قیمت واقعی نیست')),
                      ),
                  ]),
                  Text(
                      'آخرین به‌روزرسانی: ${hms(q.time)} (${ageSec}s پیش) — ${stale ? 'داده قدیمی ⚠' : 'داده معتبر'}'),
                ],
                if (m.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(m.error!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مقایسه با MT5 (اختیاری)'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _refCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'قیمت XAUUSD در MT5'),
                      onChanged: (v) => ref
                          .read(marketProvider.notifier)
                          .setReferencePrice(double.tryParse(v.trim())),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (m.referencePrice != null && q != null)
                    Text('اختلاف: ${fmt((q.mid - m.referencePrice!).abs())}'),
                ]),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('وضعیت تایم‌فریم‌ها'),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final tf in Timeframe.values.reversed)
                    Chip(
                      label: Text(
                          '${tf.label}: ${analysis?.summaries[tf] == null ? '—' : _trendFa(analysis!.summaries[tf]!.trend)}'),
                      backgroundColor: analysis?.summaries[tf] == null
                          ? null
                          : _trendColor(analysis!.summaries[tf]!.trend).withValues(alpha: 0.25),
                    ),
                ]),
              ],
            ),
          ),
        ),
        if (analysis != null && analysis.warnings.isNotEmpty)
          Card(
            color: Colors.orange.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('هشدارها'),
                  for (final w in analysis.warnings) Text('• $w', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('سیگنال‌های فعال: ${m.activeSignals.length}',
              style: theme.textTheme.titleSmall),
        ),
        if (m.signals.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('هنوز سیگنالی صادر نشده است. موتور فقط وقتی همه شرایط (امتیاز، ریسک، نسبت سود به زیان خالص ۱:۳) برقرار باشد سیگنال می‌دهد.'),
            ),
          )
        else
          SignalCard(signal: m.signals.first),
      ],
    );
  }
}
