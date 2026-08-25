import 'dart:math';
import 'package:flutter/material.dart';
import '../providers/timer_provider.dart';
import '../models/timer_settings.dart';

class CircularTimerDisplay extends StatelessWidget {
  final TimerProvider provider;

  const CircularTimerDisplay({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isCountDown = provider.settings.mode == TimerMode.countDown;
    final progress = isCountDown ? provider.progress : 0.0;
    final timeStr = provider.formatTime(provider.displaySeconds);
    final state = provider.state;

    // 状態によって色を変化
    Color ringColor;
    Color glowColor;
    if (state == TimerState.finished) {
      ringColor = const Color(0xFFFF4444); // 赤
      glowColor = const Color(0xFFFF4444);
    } else if (state == TimerState.running) {
      if (isCountDown && progress > 0.8) {
        ringColor = const Color(0xFFFF4444); // 赤（残り少ない）
        glowColor = const Color(0xFFFF4444);
      } else if (isCountDown && progress > 0.5) {
        ringColor = const Color(0xFFFFD700); // 黄
        glowColor = const Color(0xFFFFD700);
      } else {
        ringColor = const Color(0xFF44FF88); // 緑
        glowColor = const Color(0xFF44FF88);
      }
    } else if (state == TimerState.paused) {
      ringColor = const Color(0xFFFFD700); // 黄（一時停止）
      glowColor = const Color(0xFFFFD700);
    } else {
      ringColor = const Color(0xFF44FF88); // 緑（アイドル）
      glowColor = const Color(0xFF44FF88);
    }

    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 外側のグロー
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
          // ベースリング
          CustomPaint(
            size: const Size(280, 280),
            painter: _RingPainter(
              progress: isCountDown ? progress : 0.0,
              ringColor: ringColor,
              isCountDown: isCountDown,
              state: state,
            ),
          ),
          // 内側のコンテンツ
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // モードバッジ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: ringColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ringColor.withValues(alpha: 0.5)),
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
              Text(
                timeStr,
                style: TextStyle(
                  color: Colors.white,
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
              ),
              const SizedBox(height: 6),
              // 状態テキスト
              Text(
                _stateLabel(state),
                style: TextStyle(
                  color: ringColor.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final bool isCountDown;
  final TimerState state;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.isCountDown,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 8.0;
    const startAngle = -pi / 2;

    // ベーストラック（暗い）
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // プログレスアーク
    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // カウントダウン: 進捗に応じて描画
    // カウントアップ: 常に全円を薄く表示
    if (isCountDown) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        2 * pi * progress,
        false,
        progressPaint,
      );
    } else {
      // カウントアップは点滅風のパルスを表現（運行中のみ）
      if (state == TimerState.running || state == TimerState.paused) {
        progressPaint.color = ringColor.withValues(alpha: 0.6);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          2 * pi,
          false,
          progressPaint,
        );
      }
    }

    // 先端のドット
    if ((isCountDown && progress > 0) ||
        (!isCountDown &&
            (state == TimerState.running || state == TimerState.paused))) {
      final dotAngle = isCountDown
          ? startAngle + 2 * pi * progress
          : startAngle + 2 * pi;
      final dotOffset = Offset(
        center.dx + radius * cos(dotAngle),
        center.dy + radius * sin(dotAngle),
      );
      final dotPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dotOffset, 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.state != state;
}
