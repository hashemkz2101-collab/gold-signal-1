import '../core/models/candle.dart';
import '../core/models/quote.dart';
import '../core/models/timeframe.dart';

/// Contract every price source must implement. The analysis engine only sees
/// [Quote] and [Candle], so a source can be replaced without touching it.
///
/// Implementations MUST:
///  * return CLOSED candles only, ascending by time (UTC open time);
///  * leave Quote.bid / Quote.ask null when the source has no real Bid/Ask;
///  * set Quote.isMock = true for any synthetic data.
abstract class MarketDataProvider {
  String get name;
  bool get isMock;

  Future<Quote> fetchQuote();

  Future<List<Candle>> fetchCandles(Timeframe tf, {int count = 300});
}

/// Used when the user switches off test data but no real source is configured.
/// It fails loudly instead of inventing prices.
class UnconfiguredProvider implements MarketDataProvider {
  const UnconfiguredProvider();

  @override
  String get name => 'بدون منبع';

  @override
  bool get isMock => false;

  static const message =
      'هیچ منبع داده واقعی تنظیم نشده است. راهنمای docs/PROVIDERS.md را ببینید.';

  @override
  Future<Quote> fetchQuote() => Future.error(message);

  @override
  Future<List<Candle>> fetchCandles(Timeframe tf, {int count = 300}) =>
      Future.error(message);
}
