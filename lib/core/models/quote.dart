/// A price quote from a market data provider.
///
/// If the provider only supplies a reference price, [bid] and [ask] are null
/// and [mid] holds that price. The app must never present a Mid price as a
/// real Bid/Ask pair.
class Quote {
  const Quote({
    required this.mid,
    required this.time,
    required this.source,
    this.bid,
    this.ask,
    this.isMock = false,
  });

  final double? bid;
  final double? ask;
  final double mid;
  final DateTime time; // UTC
  final String source;
  final bool isMock;

  bool get hasRealBidAsk => bid != null && ask != null;

  /// Real spread, or null when the provider has no Bid/Ask.
  double? get spread => hasRealBidAsk ? ask! - bid! : null;

  Duration age(DateTime now) => now.toUtc().difference(time.toUtc());
}

enum ConnectionStatus { connecting, connected, error }
