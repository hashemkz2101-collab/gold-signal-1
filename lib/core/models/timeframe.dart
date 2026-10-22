/// Supported timeframes. Only [m1] and [m5] may produce tradable signals;
/// the others are used for context and confirmation.
enum Timeframe {
  m1(1, 'M1'),
  m5(5, 'M5'),
  m15(15, 'M15'),
  m30(30, 'M30'),
  h1(60, 'H1');

  const Timeframe(this.minutes, this.label);

  final int minutes;
  final String label;

  Duration get duration => Duration(minutes: minutes);

  bool get isTradable => this == Timeframe.m1 || this == Timeframe.m5;

  /// Relative importance used when weighting support/resistance levels.
  double get weight {
    switch (this) {
      case Timeframe.m1:
        return 0.2;
      case Timeframe.m5:
        return 0.35;
      case Timeframe.m15:
        return 0.5;
      case Timeframe.m30:
        return 0.75;
      case Timeframe.h1:
        return 1.0;
    }
  }
}
