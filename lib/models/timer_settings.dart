enum TimerMode { countUp, countDown }

class TimerSettings {
  TimerMode mode;

  /// 経過時間の読み上げアラートリスト（秒の絶対値）
  /// 経過時間がこの値になったときに読み上げる。空=読み上げなし
  /// 例: [60, 300, 600] → 1分・5分・10分経過で読み上げ
  List<int> elapsedAlerts;

  /// 残り時間の読み上げ候補リスト（秒の絶対値）
  /// 残り時間がこの値になったときに読み上げる。空=読み上げなし
  /// 例: [300, 60, 30, 10] → 残り5分・1分・30秒・10秒で読み上げ
  /// カウントアップ(上限設定時)・カウントダウン 両方に適用
  List<int> remainingAlerts;

  /// カウントダウン設定時間（秒）
  int countDownTotalSeconds;

  /// カウントアップ上限時間（秒）0=無制限
  int countUpLimitSeconds;

  TimerSettings({
    this.mode = TimerMode.countUp,
    List<int>? elapsedAlerts,
    List<int>? remainingAlerts,
    this.countDownTotalSeconds = 600,
    this.countUpLimitSeconds = 0,
  })  : elapsedAlerts = elapsedAlerts ?? [60],
        remainingAlerts = remainingAlerts ?? [];

  // ─── ラベルヘルパー ───────────────────────────────

  /// 秒数を「○分○秒」形式に変換
  static String durationLabel(int total) {
    if (total <= 0) return '0秒';
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      if (s > 0) return '$h時間$m分$s秒';
      if (m > 0) return '$h時間$m分';
      return '$h時間';
    }
    if (m > 0) return s > 0 ? '$m分$s秒' : '$m分';
    return '$s秒';
  }

  String get countDownLabel => durationLabel(countDownTotalSeconds);
  String get countUpLimitLabel =>
      countUpLimitSeconds == 0 ? '無制限' : durationLabel(countUpLimitSeconds);

  /// 経過アラートのサマリー表示用（昇順: 小さい値から）
  String get elapsedAlertsLabel {
    if (elapsedAlerts.isEmpty) return 'なし';
    final sorted = [...elapsedAlerts]..sort();
    return sorted.map(durationLabel).join(' / ');
  }

  /// 残り時間アラートのサマリー表示用（降順: 大きい値から）
  String get remainingAlertsLabel {
    if (remainingAlerts.isEmpty) return 'なし';
    final sorted = [...remainingAlerts]..sort((a, b) => b.compareTo(a));
    return sorted.map(durationLabel).join(' / ');
  }

  TimerSettings copyWith({
    TimerMode? mode,
    List<int>? elapsedAlerts,
    List<int>? remainingAlerts,
    int? countDownTotalSeconds,
    int? countUpLimitSeconds,
  }) {
    return TimerSettings(
      mode: mode ?? this.mode,
      elapsedAlerts:
          elapsedAlerts ?? List<int>.from(this.elapsedAlerts),
      remainingAlerts:
          remainingAlerts ?? List<int>.from(this.remainingAlerts),
      countDownTotalSeconds:
          countDownTotalSeconds ?? this.countDownTotalSeconds,
      countUpLimitSeconds: countUpLimitSeconds ?? this.countUpLimitSeconds,
    );
  }
}
