enum WeekParity { odd, even }

enum WeekFrequency {
  every,
  odd,
  even;

  /// Unsupported source values are deliberately treated as every week.
  static WeekFrequency parse(String text) => switch (text) {
    '每周' => every,
    '单周' => odd,
    '双周' => even,
    _ => every,
  };

  bool isCurrent(WeekParity? parity) =>
      parity == null ||
      this == every ||
      (this == odd && parity == WeekParity.odd) ||
      (this == even && parity == WeekParity.even);
}
