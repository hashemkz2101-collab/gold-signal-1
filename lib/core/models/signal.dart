enum Side { buy, sell }

enum EntryType {
  /// Enter now at the current executable price.
  immediate,

  /// Alert only: wait for price to reach [Signal.entry]. No order is placed.
  conditional,
}

enum SignalStatus { active, expired, invalidated }

enum RiskClass { normal, high }

/// One line of the score breakdown.
class ReasonItem {
  const ReasonItem(this.title, this.points, this.maxPoints, this.detail);

  final String title;
  final double points;
  final double maxPoints;
  final String detail;

  bool get passed => points >= maxPoints * 0.5;

  Map<String, Object?> toJson() =>
      {'t': title, 'p': points, 'm': maxPoints, 'd': detail};

  factory ReasonItem.fromJson(Map<String, dynamic> j) => ReasonItem(
        j['t'] as String,
        (j['p'] as num).toDouble(),
        (j['m'] as num).toDouble(),
        j['d'] as String,
      );
}

class Signal {
  const Signal({
    required this.id,
    required this.side,
    required this.timeframe,
    required this.entryType,
    required this.entry,
    required this.stopLoss,
    required this.takeProfit,
    required this.score,
    required this.riskUsd,
    required this.costUsd,
    required this.netLossUsd,
    required this.netTargetUsd,
    required this.riskClass,
    required this.createdAt,
    required this.expiresAt,
    required this.atrAtCreation,
    required this.source,
    required this.isMock,
    required this.reasons,
    this.warnings = const [],
    this.status = SignalStatus.active,
    this.statusReason,
  });

  final String id;
  final Side side;
  final String timeframe; // 'M1' or 'M5'
  final EntryType entryType;
  final double entry;
  final double stopLoss;
  final double takeProfit;

  /// Analytical quality score out of 100. NOT a win probability.
  final double score;

  /// Loss from price movement entry->stop (USD, fixed volume).
  final double riskUsd;

  /// Estimated round-trip cost (spread + commission) in USD.
  final double costUsd;
  final double netLossUsd; // riskUsd + costUsd
  final double netTargetUsd; // planned net profit after costs
  final RiskClass riskClass;
  final DateTime createdAt;
  final DateTime expiresAt;
  final double atrAtCreation;
  final String source;
  final bool isMock;
  final List<ReasonItem> reasons;
  final List<String> warnings;
  final SignalStatus status;
  final String? statusReason;

  bool get isActive => status == SignalStatus.active;
  bool get isBuy => side == Side.buy;

  Signal copyWith({SignalStatus? status, String? statusReason}) => Signal(
        id: id,
        side: side,
        timeframe: timeframe,
        entryType: entryType,
        entry: entry,
        stopLoss: stopLoss,
        takeProfit: takeProfit,
        score: score,
        riskUsd: riskUsd,
        costUsd: costUsd,
        netLossUsd: netLossUsd,
        netTargetUsd: netTargetUsd,
        riskClass: riskClass,
        createdAt: createdAt,
        expiresAt: expiresAt,
        atrAtCreation: atrAtCreation,
        source: source,
        isMock: isMock,
        reasons: reasons,
        warnings: warnings,
        status: status ?? this.status,
        statusReason: statusReason ?? this.statusReason,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'side': side.name,
        'tf': timeframe,
        'entryType': entryType.name,
        'entry': entry,
        'sl': stopLoss,
        'tp': takeProfit,
        'score': score,
        'risk': riskUsd,
        'cost': costUsd,
        'netLoss': netLossUsd,
        'netTarget': netTargetUsd,
        'riskClass': riskClass.name,
        'created': createdAt.millisecondsSinceEpoch,
        'expires': expiresAt.millisecondsSinceEpoch,
        'atr': atrAtCreation,
        'source': source,
        'mock': isMock,
        'reasons': reasons.map((e) => e.toJson()).toList(),
        'warnings': warnings,
        'status': status.name,
        'statusReason': statusReason,
      };

  factory Signal.fromJson(Map<String, dynamic> j) => Signal(
        id: j['id'] as String,
        side: Side.values.byName(j['side'] as String),
        timeframe: j['tf'] as String,
        entryType: EntryType.values.byName(j['entryType'] as String),
        entry: (j['entry'] as num).toDouble(),
        stopLoss: (j['sl'] as num).toDouble(),
        takeProfit: (j['tp'] as num).toDouble(),
        score: (j['score'] as num).toDouble(),
        riskUsd: (j['risk'] as num).toDouble(),
        costUsd: (j['cost'] as num).toDouble(),
        netLossUsd: (j['netLoss'] as num).toDouble(),
        netTargetUsd: (j['netTarget'] as num).toDouble(),
        riskClass: RiskClass.values.byName(j['riskClass'] as String),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(j['created'] as int, isUtc: true),
        expiresAt:
            DateTime.fromMillisecondsSinceEpoch(j['expires'] as int, isUtc: true),
        atrAtCreation: (j['atr'] as num).toDouble(),
        source: j['source'] as String,
        isMock: j['mock'] as bool,
        reasons: (j['reasons'] as List)
            .map((e) => ReasonItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        warnings: (j['warnings'] as List).map((e) => e as String).toList(),
        status: SignalStatus.values.byName(j['status'] as String),
        statusReason: j['statusReason'] as String?,
      );
}
