/// All user-editable settings. Defaults follow the project specification.
/// Broker/account numbers are user-entered values, NOT assumed to be valid for
/// every LiteFinance account.
class AppSettings {
  const AppSettings({
    this.symbol = 'XAUUSD',
    this.broker = 'LiteFinance',
    this.platform = 'MetaTrader 5 Mobile',
    this.accountType = 'mt5-cls-',
    this.balance = 100,
    this.leverage = 500,
    this.lots = 0.01,
    this.contractSize = 100,
    this.marginPercent = 0.2,
    this.swapBuyPoints = -89.136,
    this.swapSellPoints = 3.45,
    this.useMock = true,
    this.notificationsEnabled = true,
    this.maxDataAgeSeconds = 90,
    this.maxPriceDiff = 3.0,
    this.maxSpread = 0.60,
    this.estimatedSpread = 0.30,
    this.commissionRoundTrip = 1.0,
    this.normalRiskMax = 5.0,
    this.specialRiskMax = 10.0,
    this.allowSpecialRisk = false,
    this.minNetRR = 3.0,
    this.minScore = 65,
    this.swingStrength = 3,
    this.emaFast = 20,
    this.emaMid = 50,
    this.emaSlow = 200,
    this.rsiPeriod = 14,
    this.atrPeriod = 14,
    this.minStopAtr = 0.8,
    this.m1ExpiryMinutes = 10,
    this.m5ExpiryMinutes = 30,
  });

  final String symbol;
  final String broker;
  final String platform;
  final String accountType;
  final double balance;
  final int leverage;

  /// Fixed volume per trade. The engine never changes it to fit a risk limit.
  final double lots;
  final double contractSize; // ounces per 1.00 lot
  final double marginPercent; // 0.2 means 0.2 %
  final double swapBuyPoints; // display only, not used in calculations
  final double swapSellPoints; // display only, not used in calculations

  final bool useMock;
  final bool notificationsEnabled;

  final int maxDataAgeSeconds;
  final double maxPriceDiff; // max |source - MT5 reference| in USD
  final double maxSpread; // USD per ounce
  final double estimatedSpread; // used when the source has no Bid/Ask
  final double commissionRoundTrip; // USD per trade (estimate)

  final double normalRiskMax; // USD, price-move risk
  final double specialRiskMax; // USD
  final bool allowSpecialRisk;
  final double minNetRR; // net reward : net loss
  final int minScore;

  final int swingStrength;
  final int emaFast;
  final int emaMid;
  final int emaSlow;
  final int rsiPeriod;
  final int atrPeriod;
  final double minStopAtr;
  final int m1ExpiryMinutes;
  final int m5ExpiryMinutes;

  Map<String, Object?> toJson() => {
        'symbol': symbol,
        'broker': broker,
        'platform': platform,
        'accountType': accountType,
        'balance': balance,
        'leverage': leverage,
        'lots': lots,
        'contractSize': contractSize,
        'marginPercent': marginPercent,
        'swapBuyPoints': swapBuyPoints,
        'swapSellPoints': swapSellPoints,
        'useMock': useMock,
        'notificationsEnabled': notificationsEnabled,
        'maxDataAgeSeconds': maxDataAgeSeconds,
        'maxPriceDiff': maxPriceDiff,
        'maxSpread': maxSpread,
        'estimatedSpread': estimatedSpread,
        'commissionRoundTrip': commissionRoundTrip,
        'normalRiskMax': normalRiskMax,
        'specialRiskMax': specialRiskMax,
        'allowSpecialRisk': allowSpecialRisk,
        'minNetRR': minNetRR,
        'minScore': minScore,
        'swingStrength': swingStrength,
        'emaFast': emaFast,
        'emaMid': emaMid,
        'emaSlow': emaSlow,
        'rsiPeriod': rsiPeriod,
        'atrPeriod': atrPeriod,
        'minStopAtr': minStopAtr,
        'm1ExpiryMinutes': m1ExpiryMinutes,
        'm5ExpiryMinutes': m5ExpiryMinutes,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int i(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    bool b(String k, bool def) => (j[k] as bool?) ?? def;
    String s(String k, String def) => (j[k] as String?) ?? def;
    return AppSettings(
      symbol: s('symbol', d.symbol),
      broker: s('broker', d.broker),
      platform: s('platform', d.platform),
      accountType: s('accountType', d.accountType),
      balance: n('balance', d.balance),
      leverage: i('leverage', d.leverage),
      lots: n('lots', d.lots),
      contractSize: n('contractSize', d.contractSize),
      marginPercent: n('marginPercent', d.marginPercent),
      swapBuyPoints: n('swapBuyPoints', d.swapBuyPoints),
      swapSellPoints: n('swapSellPoints', d.swapSellPoints),
      useMock: b('useMock', d.useMock),
      notificationsEnabled: b('notificationsEnabled', d.notificationsEnabled),
      maxDataAgeSeconds: i('maxDataAgeSeconds', d.maxDataAgeSeconds),
      maxPriceDiff: n('maxPriceDiff', d.maxPriceDiff),
      maxSpread: n('maxSpread', d.maxSpread),
      estimatedSpread: n('estimatedSpread', d.estimatedSpread),
      commissionRoundTrip: n('commissionRoundTrip', d.commissionRoundTrip),
      normalRiskMax: n('normalRiskMax', d.normalRiskMax),
      specialRiskMax: n('specialRiskMax', d.specialRiskMax),
      allowSpecialRisk: b('allowSpecialRisk', d.allowSpecialRisk),
      minNetRR: n('minNetRR', d.minNetRR),
      minScore: i('minScore', d.minScore),
      swingStrength: i('swingStrength', d.swingStrength),
      emaFast: i('emaFast', d.emaFast),
      emaMid: i('emaMid', d.emaMid),
      emaSlow: i('emaSlow', d.emaSlow),
      rsiPeriod: i('rsiPeriod', d.rsiPeriod),
      atrPeriod: i('atrPeriod', d.atrPeriod),
      minStopAtr: n('minStopAtr', d.minStopAtr),
      m1ExpiryMinutes: i('m1ExpiryMinutes', d.m1ExpiryMinutes),
      m5ExpiryMinutes: i('m5ExpiryMinutes', d.m5ExpiryMinutes),
    );
  }

  /// Returns a copy with the given JSON keys replaced.
  AppSettings copyWith(Map<String, Object?> changes) =>
      AppSettings.fromJson({...toJson(), ...changes});
}
