import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/risk/risk_calculator.dart';
import 'format.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final m = ref.watch(marketProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final price = m.quote?.mid ?? 4000;
    final margin = RiskCalculator.margin(
        price: price,
        lots: s.lots,
        contractSize: s.contractSize,
        marginPercent: s.marginPercent);
    final spread = m.analysis?.spread ?? s.estimatedSpread;
    final totalCost = spread * RiskCalculator.usdPerDollarMove(s.lots, s.contractSize) +
        s.commissionRoundTrip;

    Widget field(String label, String key, double value, {String? help}) =>
        _NumField(
          label: label,
          value: value,
          help: help,
          onSubmit: (v) => notifier.update({key: v}),
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const _Header('منبع داده'),
        SwitchListTile(
          title: const Text('داده آزمایشی (ساختگی)'),
          subtitle: const Text('قیمت واقعی نیست. بدون منبع واقعی، با خاموش‌کردن آن برنامه خطا می‌دهد و قیمت جعلی نشان نمی‌دهد.'),
          value: s.useMock,
          onChanged: (v) => notifier.update({'useMock': v}),
        ),
        SwitchListTile(
          title: const Text('اعلان سیگنال'),
          value: s.notificationsEnabled,
          onChanged: (v) => notifier.update({'notificationsEnabled': v}),
        ),
        field('حداکثر عمر داده (ثانیه)', 'maxDataAgeSeconds', s.maxDataAgeSeconds.toDouble()),
        field('حداکثر اختلاف با قیمت MT5 (دلار)', 'maxPriceDiff', s.maxPriceDiff),
        const _Header('حساب و قرارداد (قابل ویرایش؛ برای همه حساب‌ها یکسان فرض نشده)'),
        ListTile(
          dense: true,
          title: Text('${s.broker} — ${s.platform} — ${s.accountType}'),
          subtitle: Text(
              'سواپ خرید ${s.swapBuyPoints} / فروش ${s.swapSellPoints} پوینت (فقط نمایشی، در محاسبه نیست)'),
        ),
        field('موجودی (دلار)', 'balance', s.balance),
        field('اهرم', 'leverage', s.leverage.toDouble()),
        field('حجم ثابت (لات)', 'lots', s.lots,
            help: 'موتور هرگز حجم را برای جا شدن در ریسک تغییر نمی‌دهد.'),
        field('اندازه قرارداد (اونس به ازای هر لات)', 'contractSize', s.contractSize),
        field('مارجین (درصد)', 'marginPercent', s.marginPercent),
        ListTile(
          dense: true,
          title: Text('مارجین تقریبی در قیمت ${fmt(price)}: ${fmt(margin)} دلار'),
          subtitle: const Text('مارجین با ریسک معامله فرق دارد.'),
        ),
        const _Header('هزینه و اسپرد'),
        field('حداکثر اسپرد مجاز (دلار)', 'maxSpread', s.maxSpread),
        field('اسپرد تخمینی (وقتی Bid/Ask نیست)', 'estimatedSpread', s.estimatedSpread),
        field('کمیسیون تخمینی رفت‌وبرگشت (دلار)', 'commissionRoundTrip', s.commissionRoundTrip),
        ListTile(
          dense: true,
          title: Text('اسپرد فعلی: ${fmt(spread)}${m.analysis?.spreadIsEstimated ?? true ? ' (تخمینی)' : ''}'),
          subtitle: Text(
              'هزینه کل تخمینی: ${fmt(totalCost)} دلار — منبع: ${m.analysis?.spreadIsEstimated ?? true ? 'تنظیمات کاربر' : 'Bid/Ask منبع داده'}'),
        ),
        const _Header('ریسک و نسبت سود به زیان'),
        field('سقف ریسک عادی (دلار حرکت قیمت)', 'normalRiskMax', s.normalRiskMax),
        field('سقف ریسک ویژه (دلار)', 'specialRiskMax', s.specialRiskMax),
        SwitchListTile(
          title: const Text('اجازه سیگنال «ریسک بالا»'),
          subtitle: const Text('پیش‌فرض خاموش. با موجودی کم بسیار خطرناک است.'),
          value: s.allowSpecialRisk,
          onChanged: (v) => notifier.update({'allowSpecialRisk': v}),
        ),
        field('حداقل نسبت سود به زیان خالص', 'minNetRR', s.minNetRR),
        field('حداقل امتیاز سیگنال', 'minScore', s.minScore.toDouble(),
            help: 'امتیاز، احتمال برد نیست.'),
        const _Header('اندیکاتورها'),
        field('قدرت Swing (کندل هر طرف)', 'swingStrength', s.swingStrength.toDouble()),
        field('EMA سریع', 'emaFast', s.emaFast.toDouble()),
        field('EMA میانی', 'emaMid', s.emaMid.toDouble()),
        field('EMA کند (نمایشی، فیلتر قطعی نیست)', 'emaSlow', s.emaSlow.toDouble()),
        field('دوره RSI', 'rsiPeriod', s.rsiPeriod.toDouble()),
        field('دوره ATR', 'atrPeriod', s.atrPeriod.toDouble()),
        field('حداقل فاصله حد ضرر (ضریب ATR)', 'minStopAtr', s.minStopAtr),
        field('اعتبار سیگنال M1 (دقیقه)', 'm1ExpiryMinutes', s.m1ExpiryMinutes.toDouble()),
        field('اعتبار سیگنال M5 (دقیقه)', 'm5ExpiryMinutes', s.m5ExpiryMinutes.toDouble()),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _NumField extends StatefulWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onSubmit,
    this.help,
  });

  final String label;
  final double value;
  final String? help;
  final void Function(double) onSubmit;

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: _text(widget.value));
  }

  String _text(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _commit() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    if (v == null) {
      _c.text = _text(widget.value);
      return;
    }
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Focus(
        onFocusChange: (focused) {
          if (!focused) _commit();
        },
        child: TextField(
          controller: _c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.help,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _commit(),
        ),
      ),
    );
  }
}
