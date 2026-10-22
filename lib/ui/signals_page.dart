import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'signal_card.dart';

class SignalsPage extends ConsumerWidget {
  const SignalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(marketProvider);
    final rejections = m.analysis?.rejections ?? const [];
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [
            Tab(text: 'فعال'),
            Tab(text: 'تاریخچه'),
            Tab(text: 'چرا سیگنال نیست؟'),
          ]),
          Expanded(
            child: TabBarView(children: [
              _list(m.activeSignals.isEmpty
                  ? const [Padding(padding: EdgeInsets.all(16), child: Text('سیگنال فعالی وجود ندارد.'))]
                  : [for (final s in m.activeSignals) SignalCard(signal: s, expanded: true)]),
              ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: () => ref.read(marketProvider.notifier).clearHistory(),
                      child: const Text('پاک‌کردن تاریخچه'),
                    ),
                  ),
                  for (final s in m.signals.where((e) => !e.isActive)) SignalCard(signal: s, expanded: true),
                ],
              ),
              _list([
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('دلیل ردشدن کاندیدهای آخرین تحلیل:'),
                ),
                if (rejections.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('—')),
                for (final r in rejections)
                  ListTile(
                    dense: true,
                    title: Text(r.reason),
                    subtitle: Text(
                        '${r.timeframe?.label ?? 'همه'} ${r.side == null ? '' : (r.side!.name == 'buy' ? 'خرید' : 'فروش')}'),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _list(List<Widget> children) =>
      ListView(padding: const EdgeInsets.all(12), children: children);
}
