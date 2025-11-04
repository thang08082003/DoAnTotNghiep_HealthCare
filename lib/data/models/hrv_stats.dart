class HrvStats {
  final double rmssd;
  final double sdnn;
  final double pnn50;
  final double hr;
  final int score;
  final String level;

  const HrvStats({
    required this.rmssd,
    required this.sdnn,
    required this.pnn50,
    required this.hr,
    required this.score,
    required this.level,
  });

  static const empty = HrvStats(
    rmssd: double.nan,
    sdnn: double.nan,
    pnn50: double.nan,
    hr: double.nan,
    score: 0,
    level: 'low',
  );
}
