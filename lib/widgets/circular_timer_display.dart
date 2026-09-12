import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/timer_provider.dart';
import '../models/timer_settings.dart';

// ════════════════════════════════════════════════
//  CircularTimerDisplay — ドラッグシーク対応
// ════════════════════════════════════════════════
class CircularTimerDisplay extends StatefulWidget {
  final TimerProvider provider;

  const CircularTimerDisplay({super.key, required this.provider});

  @override
  State<CircularTimerDisplay> createState() => _CircularTimerDisplayState();
}

class _CircularTimerDisplayState extends State<CircularTimerDisplay> {
  double? _dragProgress;
  bool _isDragging = false;

  static const double _size = 280.0;
  static const double _strokeWidth = 12.0;
  static const double _hitSlop = 28.0;

  double get _radius => _size / 2 - _strokeWidth / 2;

  // ── ドットのプログレス計算（常時表示用）──────────────
  // カウントアップ上限なし: 60秒1周期で時計回り
  // カウントアップ上限あり: 0→limit を0.0→1.0でマッピング
  // カウントダウン        : 経過/total を0.0→1.0でマッピング
  double _calcDotProgress() {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (_isDragging) {
      return _dragProgress ?? 0.0;
    }

    if (isCountDown) {
      // カウントダウン: 経過時間ベースでドット移動（0=開始 → 1=終了）
      final total = p.settings.countDownTotalSeconds;
      if (total == 0) return 0.0;
      return (p.elapsedSeconds / total).clamp(0.0, 1.0);
    } else {
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        // 上限あり: 経過/上限
        return (p.elapsedSeconds / limit).clamp(0.0, 1.0);
      } else {
        // 上限なし: 60秒で1周（常時グルグル回る）
        return (p.elapsedSeconds % 60) / 60.0;
      }
    }
  }

  // ── アーク表示用プログレス（リングの塗り具合）────────
  double _calcArcProgress() {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (_isDragging) {
      return _dragProgress ?? 0.0;
    }

    if (isCountDown) {
      // カウントダウン: 残り時間が減るにつれてアーク伸長
      return p.progress; // 既存の progress（経過/total）
    } else {
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        return (p.elapsedSeconds / limit).clamp(0.0, 1.0);
      } else {
        // 上限なし: アークは常に全周（薄く表示）
        return 1.0;
      }
    }
  }

  // ── 座標 → プログレス（0.0〜1.0、12時=0）────────────
  double _offsetToProgress(Offset localPos) {
    const center = Offset(_size / 2, _size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    double angle = atan2(dy, dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;
    return angle / (2 * pi);
  }

  // ── タッチがリング上かを判定 ──────────────────────────
  bool _isOnRing(Offset localPos) {
    const center = Offset(_size / 2, _size / 2);
    final dist = (localPos - center).distance;
    return (dist - _radius).abs() < _hitSlop;
  }

  // ── プログレス → 絶対秒数 → provider にシーク ────────
  void _applyProgress(double progress) {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (isCountDown) {
      final total = p.settings.countDownTotalSeconds;
      // ドット位置 = 経過割合 → 残り = total - elapsed
      final elapsed = (total * progress).round().clamp(0, total);
      final remaining = total - elapsed;
      p.seekTo(remaining);
    } else {
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        final elapsed = (limit * progress).round().clamp(0, limit);
        p.seekTo(elapsed);
      } else {
        // 上限なし: 60秒単位でシーク（現在の周回数を維持）
        final currentLap = p.elapsedSeconds ~/ 60;
        final newElapsed = currentLap * 60 + (60 * progress).round();
        p.seekTo(newElapsed.clamp(0, 99 * 3600));
      }
    }
  }

  // ── ドラッグ中の時間文字列 ─────────────────────────────
  String _dragTimeStr() {
    final prog = _dragProgress ?? 0.0;
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (isCountDown) {
      final total = p.settings.countDownTotalSeconds;
      final elapsed = (total * prog).round().clamp(0, total);
      final remaining = total - elapsed;
      return p.formatTime(remaining);
    } else {
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        final elapsed = (limit * prog).round().clamp(0, limit);
        return p.formatTime(elapsed);
      } else {
        final currentLap = p.elapsedSeconds ~/ 60;
        final newElapsed = currentLap * 60 + (60 * prog).round();
        return p.formatTime(newElapsed.clamp(0, 99 * 3600));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;
    final state = p.state;
    final canDrag = state == TimerState.running || state == TimerState.paused;

    final dotProgress  = _calcDotProgress();
    final arcProgress  = _calcArcProgress();
    final timeStr = _isDragging ? _dragTimeStr() : p.formatTime(p.displaySeconds);

    // ── カラー決定 ──────────────────────────────────────
    Color ringColor;
    Color glowColor;
    if (_isDragging) {
      ringColor = const Color(0xFF44AAFF);
      glowColor = const Color(0xFF44AAFF);
    } else if (state == TimerState.finished) {
      ringColor = const Color(0xFFFF4444);
      glowColor = const Color(0xFFFF4444);
    } else if (state == TimerState.running) {
      if (isCountDown && arcProgress > 0.8) {
        ringColor = const Color(0xFFFF4444);
        glowColor = const Color(0xFFFF4444);
      } else if (isCountDown && arcProgress > 0.5) {
        ringColor = const Color(0xFFFFD700);
        glowColor = const Color(0xFFFFD700);
      } else {
        ringColor = const Color(0xFF44FF88);
        glowColor = const Color(0xFF44FF88);
      }
    } else if (state == TimerState.paused) {
      ringColor = const Color(0xFFFFD700);
      glowColor = const Color(0xFFFFD700);
    } else {
      ringColor = const Color(0xFF44FF88);
      glowColor = const Color(0xFF44FF88);
    }

    // ── ドット表示判定 ────────────────────────────────
    final showDot = state == TimerState.running ||
        state == TimerState.paused ||
        _isDragging;

    Widget timerWidget = SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外側グロー
          Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(
                      alpha: _isDragging ? 0.3 : 0.15),
                  blurRadius: _isDragging ? 55 : 40,
                  spreadRadius: _isDragging ? 14 : 10,
                ),
              ],
            ),
          ),
          // リング + ドット
          CustomPaint(
            size: const Size(_size, _size),
            painter: _RingPainter(
              arcProgress: arcProgress,
              dotProgress: dotProgress,
              ringColor: ringColor,
              isCountDown: isCountDown,
              state: state,
              isDragging: _isDragging,
              strokeWidth: _strokeWidth,
              showDot: showDot,
            ),
          ),
          // 中央コンテンツ
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // モードバッジ
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ringColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: ringColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isCountDown ? '▼ COUNT DOWN' : '▲ COUNT UP',
                  style: TextStyle(
                    color: ringColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 時間表示
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 80),
                style: TextStyle(
                  color: _isDragging
                      ? const Color(0xFF44AAFF)
                      : Colors.white,
                  fontSize: timeStr.length > 5 ? 48 : 56,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  shadows: [
                    Shadow(
                      color: ringColor.withValues(alpha: 0.8),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Text(timeStr),
              ),
              const SizedBox(height: 6),
              // 状態テキスト
              Text(
                _isDragging ? 'SEEKING...' : _stateLabel(state),
                style: TextStyle(
                  color: ringColor.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
              if (_isDragging) ...[
                const SizedBox(height: 4),
                Text(
                  '指を離して確定',
                  style: TextStyle(
                    color: const Color(0xFF44AAFF).withValues(alpha: 0.7),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
          // ドラッグヒント
          if (canDrag && !_isDragging)
            Positioned(
              bottom: 18,
              child: Text(
                '⟳ リングをドラッグで時間調整',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );

    if (!canDrag) return timerWidget;

    return GestureDetector(
      onPanStart: (details) {
        if (!_isOnRing(details.localPosition)) return;
        final prog = _offsetToProgress(details.localPosition);
        setState(() {
          _isDragging = true;
          _dragProgress = prog;
        });
        HapticFeedback.selectionClick();
      },
      onPanUpdate: (details) {
        if (!_isDragging) return;
        setState(() {
          _dragProgress = _offsetToProgress(details.localPosition);
        });
      },
      onPanEnd: (_) {
        if (!_isDragging) return;
        final prog = _dragProgress ?? _calcDotProgress();
        setState(() {
          _isDragging = false;
          _dragProgress = null;
        });
        _applyProgress(prog);
        HapticFeedback.mediumImpact();
      },
      onPanCancel: () {
        setState(() {
          _isDragging = false;
          _dragProgress = null;
        });
      },
      child: timerWidget,
    );
  }

  String _stateLabel(TimerState state) {
    switch (state) {
      case TimerState.idle:     return 'READY';
      case TimerState.running:  return 'RUNNING';
      case TimerState.paused:   return 'PAUSED';
      case TimerState.finished: return 'FINISHED';
    }
  }
}

// ════════════════════════════════════════════════
//  リングペインター
// ════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double arcProgress;  // アーク（塗り）用
  final double dotProgress;  // ドット位置用
  final Color ringColor;
  final bool isCountDown;
  final TimerState state;
  final bool isDragging;
  final double strokeWidth;
  final bool showDot;

  _RingPainter({
    required this.arcProgress,
    required this.dotProgress,
    required this.ringColor,
    required this.isCountDown,
    required this.state,
    required this.isDragging,
    required this.strokeWidth,
    required this.showDot,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    const startAngle = -pi / 2; // 12時位置

    // ── ベーストラック ──────────────────────────────
    final trackPaint = Paint()
      ..color = Colors.white.withValues(
          alpha: isDragging ? 0.14 : 0.08)
      ..strokeWidth = isDragging ? strokeWidth + 2 : strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // ── プログレスアーク ────────────────────────────
    final progressPaint = Paint()
      ..strokeWidth = isDragging ? strokeWidth + 3 : strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final isCountUpNoLimit = !isCountDown &&
        state != TimerState.idle &&
        state != TimerState.finished;

    if (isCountDown || isDragging) {
      // カウントダウン / ドラッグ中: アークを progress 分描画
      if (arcProgress > 0) {
        progressPaint.color = ringColor;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          (2 * pi * arcProgress).clamp(0.001, 2 * pi),
          false,
          progressPaint,
        );
      }
    } else if (isCountUpNoLimit) {
      // カウントアップ上限なし: 全周を薄く表示
      progressPaint.color = ringColor.withValues(alpha: 0.45);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi,
        false,
        progressPaint,
      );
    } else if (!isCountDown) {
      // カウントアップ上限あり: arcProgress 分描画
      if (arcProgress > 0) {
        progressPaint.color = ringColor;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          (2 * pi * arcProgress).clamp(0.001, 2 * pi),
          false,
          progressPaint,
        );
      }
    }

    // ── ドット（ハンドル）───────────────────────────
    if (showDot) {
      final dotAngle = startAngle + 2 * pi * dotProgress;
      final dotOffset = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );

      if (isDragging) {
        // グロー
        canvas.drawCircle(
          dotOffset, 18,
          Paint()
            ..color = ringColor.withValues(alpha: 0.35)
            ..style = PaintingStyle.fill,
        );
        // 外枠
        canvas.drawCircle(
          dotOffset, 12,
          Paint()
            ..color = ringColor.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      // 本体ドット
      canvas.drawCircle(
        dotOffset,
        isDragging ? 9 : 7,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.fill,
      );

      // 白い中心点（ドラッグ中）
      if (isDragging) {
        canvas.drawCircle(
          dotOffset, 4,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.arcProgress != arcProgress ||
      old.dotProgress != dotProgress ||
      old.ringColor != ringColor ||
      old.state != state ||
      old.isDragging != isDragging ||
      old.showDot != showDot;
}
