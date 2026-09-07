enum WeekParity { odd, even }

enum PreviewMode { current, odd, even, all }

enum WeekFrequency {
  every,
  odd,
  even,
  unknown;

  /// Source tokens are exact. Unknown text belongs on the meeting unchanged.
  static WeekFrequency parse(String text) => switch (text) {
    '每周' => every,
    '单周' => odd,
    '双周' => even,
    _ => unknown,
  };

  bool isVisible({
    PreviewMode mode = PreviewMode.current,
    WeekParity? currentParity,
  }) {
    final parity = switch (mode) {
      PreviewMode.current => currentParity,
      PreviewMode.odd => WeekParity.odd,
      PreviewMode.even => WeekParity.even,
      PreviewMode.all => null,
    };
    return parity == null ||
        this == every ||
        this == unknown ||
        (this == odd && parity == WeekParity.odd) ||
        (this == even && parity == WeekParity.even);
  }
}
