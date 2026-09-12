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
  // ドラッグ中の仮プログレス（0.0〜1.0）
  double? _dragProgress;
  // ドラッグ中かどうか
  bool _isDragging = false;

  static const double _size = 280.0;
  static const double _strokeWidth = 12.0;
  // タッチ判定を広げるための許容範囲（px）
  static const double _hitSlop = 28.0;

  double get _radius => _size / 2 - _strokeWidth / 2;

  // 座標 → 角度（0.0〜1.0、12時=0, 時計回り）
  double _offsetToProgress(Offset localPos) {
    const center = Offset(_size / 2, _size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    // atan2 は右=0, 上=-π/2 → 12時を0にするため +π/2
    double angle = atan2(dy, dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;
    return angle / (2 * pi);
  }

  // タッチ点がリング上かを判定
  bool _isOnRing(Offset localPos) {
    const center = Offset(_size / 2, _size / 2);
    final dist = (localPos - center).distance;
    return (dist - _radius).abs() < _hitSlop;
  }

  // プログレス → 絶対秒数に変換して provider にシーク
  void _applyProgress(double progress) {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (isCountDown) {
      final total = p.settings.countDownTotalSeconds;
      // progress 0=開始(残り=total), 1=終了(残り=0)
      // ただしドラッグで自然に感じるよう: progress が大きい=消費が多い=残り少ない
      final remaining = (total * (1.0 - progress)).round().clamp(0, total);
      p.seekTo(remaining);
    } else {
      // カウントアップ: 上限がある場合のみ円弧が意味を持つ
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        final elapsed = (limit * progress).round().clamp(0, limit);
        p.seekTo(elapsed);
      } else {
        // 無制限カウントアップ: 最大 99時間 でマッピング
        const maxSec = 99 * 3600;
        final elapsed = (maxSec * progress).round().clamp(0, maxSec);
        p.seekTo(elapsed);
      }
    }
  }

  // ドラッグ中の表示秒数を計算（リアルタイムプレビュー用）
  String _dragTimeStr() {
    final prog = _dragProgress ?? 0.0;
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;

    if (isCountDown) {
      final total = p.settings.countDownTotalSeconds;
      final remaining = (total * (1.0 - prog)).round().clamp(0, total);
      return p.formatTime(remaining);
    } else {
      final limit = p.settings.countUpLimitSeconds;
      if (limit > 0) {
        final elapsed = (limit * prog).round().clamp(0, limit);
        return p.formatTime(elapsed);
      } else {
        const maxSec = 99 * 3600;
        final elapsed = (maxSec * prog).round().clamp(0, maxSec);
        return p.formatTime(elapsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final isCountDown = p.settings.mode == TimerMode.countDown;
    final state = p.state;
    final canDrag =
        state == TimerState.running || state == TimerState.paused;

    // 表示用プログレス: ドラッグ中は仮値、それ以外は実値
    final displayProgress = _isDragging
        ? (_dragProgress ?? p.progress)
        : p.progress;

    final timeStr = _isDragging ? _dragTimeStr() : p.formatTime(p.displaySeconds);

    // カラー決定
    Color ringColor;
    Color glowColor;
    if (_isDragging) {
      ringColor = const Color(0xFF44AAFF); // ドラッグ中は青
      glowColor = const Color(0xFF44AAFF);
    } else if (state == TimerState.finished) {
      ringColor = const Color(0xFFFF4444);
      glowColor = const Color(0xFFFF4444);
    } else if (state == TimerState.running) {
      if (isCountDown && displayProgress > 0.8) {
        ringColor = const Color(0xFFFF4444);
        glowColor = const Color(0xFFFF4444);
      } else if (isCountDown && displayProgress > 0.5) {
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
                  color: glowColor.withValues(alpha: _isDragging ? 0.3 : 0.15),
                  blurRadius: _isDragging ? 55 : 40,
                  spreadRadius: _isDragging ? 14 : 10,
                ),
              ],
            ),
          ),
          // リングペインター
          CustomPaint(
            size: const Size(_size, _size),
            painter: _RingPainter(
              progress: isCountDown ? displayProgress : displayProgress,
              ringColor: ringColor,
              isCountDown: isCountDown,
              state: state,
              isDragging: _isDragging,
              strokeWidth: _strokeWidth,
            ),
          ),
          // 中央コンテンツ
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // モードバッジ
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ringColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: ringColor.withValues(alpha: 0.5)),
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
                  color: _isDragging ? const Color(0xFF44AAFF) : Colors.white,
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
              // ドラッグ中のヒントテキスト
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
          // ドラッグ可能リングへのヒント（アイドル以外で非ドラッグ時）
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

    // ドラッグ操作のラッピング
    if (!canDrag) return timerWidget;

    return GestureDetector(
      onPanStart: (details) {
        final localPos = details.localPosition;
        if (!_isOnRing(localPos)) return;
        final prog = _offsetToProgress(localPos);
        setState(() {
          _isDragging = true;
          _dragProgress = prog;
        });
        HapticFeedback.selectionClick();
      },
      onPanUpdate: (details) {
        if (!_isDragging) return;
        final localPos = details.localPosition;
        final prog = _offsetToProgress(localPos);
        setState(() {
          _dragProgress = prog;
        });
      },
      onPanEnd: (_) {
        if (!_isDragging) return;
        final prog = _dragProgress ?? widget.provider.progress;
        setState(() {
          _isDragging = false;
          _dragProgress = null;
        });
        _applyProgress(prog);
        HapticFeedback.mediumImpact();
      },
      onPanCancel: () {
        if (!_isDragging) return;
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
      case TimerState.idle:
        return 'READY';
      case TimerState.running:
        return 'RUNNING';
      case TimerState.paused:
        return 'PAUSED';
      case TimerState.finished:
        return 'FINISHED';
    }
  }
}

// ════════════════════════════════════════════════
//  リングペインター
// ════════════════════════════════════════════════
class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool isCountDown;
  final TimerState state;
  final bool isDragging;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.isCountDown,
    required this.state,
    required this.isDragging,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - strokeWidth / 2;
    const startAngle = -pi / 2; // 12時位置

    // ── ベーストラック ──
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDragging ? 0.14 : 0.08)
      ..strokeWidth = isDragging ? strokeWidth + 2 : strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // ── プログレスアーク ──
    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = isDragging ? strokeWidth + 3 : strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final showArc = isCountDown
        ? progress > 0
        : (state == TimerState.running ||
            state == TimerState.paused ||
            isDragging);

    if (showArc) {
      final sweepAngle = isCountDown
          ? 2 * pi * progress
          : (isDragging ? 2 * pi * progress : 2 * pi);
      final effectiveSweep = sweepAngle.clamp(0.001, 2 * pi);

      if (!isCountDown && !isDragging) {
        progressPaint.color = ringColor.withValues(alpha: 0.6);
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        effectiveSweep,
        false,
        progressPaint,
      );
    }

    // ── ドラッグハンドル（大きめドット）──
    final showDot = showArc;
    if (showDot) {
      final dotAngle = isCountDown
          ? startAngle + 2 * pi * progress
          : (isDragging
              ? startAngle + 2 * pi * progress
              : startAngle + 2 * pi);
      final dotOffset = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );

      // 外側のリング（ドラッグ中は強調）
      if (isDragging) {
        final glowPaint = Paint()
          ..color = ringColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotOffset, 18, glowPaint);

        final borderPaint = Paint()
          ..color = ringColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(dotOffset, 12, borderPaint);
      }

      // 中心ドット
      final dotPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotOffset, isDragging ? 9 : 6, dotPaint);

      // ドラッグ中の白い中心点
      if (isDragging) {
        final innerPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(dotOffset, 4, innerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.state != state ||
      oldDelegate.isDragging != isDragging;
}
