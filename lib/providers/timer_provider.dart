import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/timer_settings.dart';
import '../services/tts_service.dart';

enum TimerState { idle, running, paused, finished }

class TimerProvider extends ChangeNotifier {
  final TtsService _tts = TtsService();
  Timer? _timer;

  TimerSettings _settings = TimerSettings();
  TimerState _state = TimerState.idle;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;

  // 経過読み上げ: 発火済みの絶対値秒数のSet（カウントアップ専用）
  final Set<int> _spokenElapsed = {};
  // 残り時間読み上げ: すでに発火済みの候補秒数のSet
  final Set<int> _spokenRemainingAlerts = {};

  TimerSettings get settings => _settings;
  TimerState get state => _state;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _state == TimerState.running;
  bool get isPaused => _state == TimerState.paused;
  bool get isIdle => _state == TimerState.idle;
  bool get isFinished => _state == TimerState.finished;

  /// 表示用の秒数（カウントアップ→経過, カウントダウン→残り）
  int get displaySeconds =>
      _settings.mode == TimerMode.countUp ? _elapsedSeconds : _remainingSeconds;

  /// 進捗 0.0〜1.0
  double get progress {
    if (_settings.mode == TimerMode.countDown) {
      final total = _settings.countDownTotalSeconds;
      if (total == 0) return 0.0;
      return 1.0 - (_remainingSeconds / total);
    }
    if (_settings.countUpLimitSeconds > 0) {
      return (_elapsedSeconds / _settings.countUpLimitSeconds).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  /// カウントアップの残り（上限 - 経過）
  int get countUpRemainingSeconds {
    if (_settings.countUpLimitSeconds <= 0) return 0;
    return (_settings.countUpLimitSeconds - _elapsedSeconds)
        .clamp(0, _settings.countUpLimitSeconds);
  }

  /// 次の経過アラートまでの残り秒数（UI表示用）
  int? get secondsUntilNextElapsed {
    final alerts = _settings.elapsedAlerts;
    if (alerts.isEmpty) return null;
    int? minRemaining;
    for (final alertAt in alerts) {
      if (alertAt <= 0) continue;
      if (alertAt <= _elapsedSeconds) continue;
      final rem = alertAt - _elapsedSeconds;
      if (minRemaining == null || rem < minRemaining) {
        minRemaining = rem;
      }
    }
    return minRemaining;
  }

  // ─── 設定更新 ─────────────────────────────────────

  void updateSettings(TimerSettings newSettings) {
    final wasActive =
        _state == TimerState.running || _state == TimerState.paused;

    _settings = newSettings;

    if (!wasActive) {
      _resetCounters(notify: false);
    }
    notifyListeners();
  }

  /// 手動で時間を進める / 戻す（running / paused 中のみ有効）
  /// deltaSec が正 → 進める、負 → 戻す
  void seekBy(int deltaSec) {
    if (_state == TimerState.idle || _state == TimerState.finished) return;
    if (deltaSec == 0) return;

    if (_settings.mode == TimerMode.countUp) {
      final limit = _settings.countUpLimitSeconds;
      final maxSec = limit > 0 ? limit : 99 * 3600;
      _elapsedSeconds = (_elapsedSeconds + deltaSec).clamp(0, maxSec);
      // 上限を超えた場合は終了扱い
      if (limit > 0 && _elapsedSeconds >= limit) {
        _elapsedSeconds = limit;
        _onLimitReached();
        return;
      }
    } else {
      // カウントダウン: remaining と elapsed を連動させる
      final total = _settings.countDownTotalSeconds;
      // deltaSecを進める方向 = 残り時間を減らす
      _remainingSeconds = (_remainingSeconds - deltaSec).clamp(0, total);
      _elapsedSeconds   = (total - _remainingSeconds).clamp(0, total);
      if (_remainingSeconds == 0) {
        _onCountDownFinished();
        return;
      }
    }

    // 読み上げ済みSetを現在位置に合わせてリセット
    // （現在経過秒数より小さい経過アラートは「済み」として保持）
    _spokenElapsed.removeWhere((s) => s > _elapsedSeconds);
    // 残り時間アラートも同様に現在残り時間より大きいもの（まだ来ていないもの）を復活
    final currentRem = _settings.mode == TimerMode.countUp
        ? countUpRemainingSeconds
        : _remainingSeconds;
    _spokenRemainingAlerts.removeWhere((s) => s >= currentRem);

    notifyListeners();
  }

  /// 動作中でも経過アラートリストを即時変更
  void updateElapsedAlerts(List<int> newAlerts) {
    _settings = _settings.copyWith(elapsedAlerts: List<int>.from(newAlerts));
    notifyListeners();
  }

  /// 動作中でも残り時間アラートリストを即時変更
  void updateRemainingAlerts(List<int> newAlerts) {
    _settings = _settings.copyWith(remainingAlerts: List<int>.from(newAlerts));
    notifyListeners();
  }

  // ─── タイマー操作 ──────────────────────────────────

  Future<void> start() async {
    if (_state == TimerState.running) return;
    if (_state == TimerState.idle || _state == TimerState.finished) {
      _resetCounters(notify: false);
    }
    _state = TimerState.running;
    notifyListeners();
    await _tts.init();
    await _tts.announceStart();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  Future<void> pause() async {
    if (_state != TimerState.running) return;
    _timer?.cancel();
    _state = TimerState.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_state != TimerState.paused) return;
    _state = TimerState.running;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  Future<void> stop() async {
    if (_state == TimerState.idle) return;
    _timer?.cancel();
    await _tts.stop();
    await _tts.announceStop();
    _resetCounters(notify: false);
    _state = TimerState.idle;
    notifyListeners();
  }

  void _tick(Timer t) {
    if (_settings.mode == TimerMode.countUp) {
      _elapsedSeconds++;
      _checkAnnounceElapsed();
      _checkAnnounceCountUpRemaining();
      if (_settings.countUpLimitSeconds > 0 &&
          _elapsedSeconds >= _settings.countUpLimitSeconds) {
        _onLimitReached();
        return;
      }
    } else {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        _checkAnnounceElapsed();      // カウントダウン中も経過アラートを発火
        _checkAnnounceCountDown();
        if (_remainingSeconds == 0) {
          _onCountDownFinished();
          return;
        }
      }
    }
    notifyListeners();
  }

  // ─── 経過時間読み上げ（カウントアップ）────────────────

  void _checkAnnounceElapsed() {
    if (_settings.elapsedAlerts.isEmpty) return;
    if (_settings.elapsedAlerts.contains(_elapsedSeconds) &&
        !_spokenElapsed.contains(_elapsedSeconds)) {
      _spokenElapsed.add(_elapsedSeconds);
      _speakElapsed(_elapsedSeconds);
    }
  }

  // ─── カウントアップ残り時間読み上げ ──────────────────

  void _checkAnnounceCountUpRemaining() {
    if (_settings.remainingAlerts.isEmpty) return;
    if (_settings.countUpLimitSeconds <= 0) return;
    final rem = countUpRemainingSeconds;
    if (rem <= 0) return;
    if (_settings.remainingAlerts.contains(rem) &&
        !_spokenRemainingAlerts.contains(rem)) {
      _spokenRemainingAlerts.add(rem);
      _speakRemaining(rem);
    }
  }

  // ─── カウントダウン残り時間読み上げ ──────────────────

  void _checkAnnounceCountDown() {
    final rem = _remainingSeconds;
    if (rem <= 0) return;
    if (_settings.remainingAlerts.contains(rem) &&
        !_spokenRemainingAlerts.contains(rem)) {
      _spokenRemainingAlerts.add(rem);
      _speakRemaining(rem);
    }
  }

  // ─── TTS ヘルパー ────────────────────────────────────

  void _speakElapsed(int sec) {
    if (sec >= 60 && sec % 60 == 0) {
      _tts.announceElapsedMinutes(sec ~/ 60);
    } else if (sec < 60) {
      _tts.announceElapsedSeconds(sec);
    } else {
      final m = sec ~/ 60;
      final s = sec % 60;
      _tts.speak('$m分$s秒経過');
    }
  }

  void _speakRemaining(int sec) {
    if (sec >= 60 && sec % 60 == 0) {
      _tts.announceRemainingMinutes(sec ~/ 60);
    } else if (sec < 60) {
      _tts.announceRemainingSeconds(sec);
    } else {
      final m = sec ~/ 60;
      final s = sec % 60;
      _tts.speak('残り時間$m分$s秒');
    }
  }

  // ─── 終了処理 ────────────────────────────────────────

  Future<void> _onCountDownFinished() async {
    _timer?.cancel();
    _state = TimerState.finished;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.announceStop();
  }

  Future<void> _onLimitReached() async {
    _timer?.cancel();
    _state = TimerState.finished;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    await _tts.announceStop();
  }

  void _resetCounters({bool notify = true}) {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _remainingSeconds = _settings.countDownTotalSeconds;
    _spokenElapsed.clear();
    _spokenRemainingAlerts.clear();
    _state = TimerState.idle;
    if (notify) notifyListeners();
  }

  void reset() => _resetCounters();

  String formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.dispose();
    super.dispose();
  }
}
