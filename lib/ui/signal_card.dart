import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/signal.dart';
import 'format.dart';

class SignalCard extends StatelessWidget {
  const SignalCard({super.key, required this.signal, this.expanded = false});

  final Signal signal;
  final bool expanded;

  Future<void> _copy(BuildContext context) async {
    final s = signal;
    if (s.riskClass == RiskClass.high) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('هشدار ریسک بالا'),
          content: const Text(
              'این معامله «ریسک بالا» است. با موجودی کم، چند زیان متوالی می‌تواند بخش بزرگی از موجودی را از بین ببرد. ادامه می‌دهید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('کپی')),
          ],
        ),
      );
      if (ok != true) return;
    }
    final text = '${s.isBuy ? 'BUY' : 'SELL'} XAUUSD ${s.timeframe}\n'
        'Entry: ${fmt(s.entry)}\nSL: ${fmt(s.stopLoss)}\nTP: ${fmt(s.takeProfit)}';
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('کپی شد. معامله را خودتان در MT5 ثبت کنید.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = signal;
    final color = s.isBuy ? Colors.green : Colors.red;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Chip(
                label: Text('${s.isBuy ? 'خرید' : 'فروش'} ${s.timeframe}'),
                backgroundColor: color.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              Text('امتیاز ${fmt(s.score, 0)}/100', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (s.isMock) const Chip(label: Text('آزمایشی')),
            ]),
            Wrap(spacing: 6, children: [
              if (s.entryType == EntryType.conditional) const Chip(label: Text('ورود مشروط (فقط هشدار)')),
              if (s.riskClass == RiskClass.high)
                Chip(label: const Text('ریسک بالا'), backgroundColor: Colors.orange.withValues(alpha: 0.3)),
              if (!s.isActive)
                Chip(label: Text(s.status == SignalStatus.expired ? 'منقضی' : 'لغو شده')),
            ]),
            const SizedBox(height: 6),
            Text('ورود ${fmt(s.entry)}   |   حد ضرر ${fmt(s.stopLoss)}   |   حد سود ${fmt(s.takeProfit)}'),
            Text(
                'ریسک قیمتی ${fmt(s.riskUsd)}\$ + هزینه تخمینی ${fmt(s.costUsd)}\$ = زیان خالص ${fmt(s.netLossUsd)}\$ → هدف سود خالص ${fmt(s.netTargetUsd)}\$'),
            Text('ایجاد ${hms(s.createdAt)} — انقضا ${hms(s.expiresAt)} — منبع: ${s.source}',
                style: theme.textTheme.bodySmall),
            if (s.statusReason != null) Text(s.statusReason!, style: theme.textTheme.bodySmall),
            if (expanded) ...[
              const Divider(),
              for (final r in s.reasons)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(r.passed ? Icons.check_circle : Icons.cancel,
                          size: 16, color: r.passed ? Colors.green : Colors.red),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${r.title} (${fmt(r.points, 0)}/${fmt(r.maxPoints, 0)}): ${r.detail}')),
                    ],
                  ),
                ),
              for (final w in s.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('⚠ $w', style: theme.textTheme.bodySmall),
                ),
              const SizedBox(height: 4),
              const Text('امتیاز، کیفیت تحلیلی است و احتمال سود نیست. حد ضرر زیان را تضمین نمی‌کند (لغزش و گپ ممکن است).',
                  style: TextStyle(fontSize: 11)),
            ],
            if (s.isActive)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('کپی اطلاعات'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
