import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/timer_provider.dart';
import '../models/timer_settings.dart';
import '../widgets/circular_timer_display.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: CircularTimerDisplay(provider: provider),
                  ),
                ),
                _buildNextAnnouncement(provider),
                const SizedBox(height: 16),
                _buildControls(context, provider),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── ヘッダー ───────────────────────────────────
  Widget _buildHeader(BuildContext context, TimerProvider provider) {
    final s = provider.settings;
    String subText;
    if (s.mode == TimerMode.countDown) {
      subText = '${s.countDownLabel}  |  経過:${s.elapsedAlertsLabel}';
    } else if (s.countUpLimitSeconds > 0) {
      final remPart = s.remainingAlerts.isNotEmpty
          ? '  残り:${s.remainingAlertsLabel}'
          : '';
      subText = '上限:${s.countUpLimitLabel}  経過:${s.elapsedAlertsLabel}$remPart';
    } else {
      subText = '無制限  |  経過:${s.elapsedAlertsLabel}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: const TextSpan(children: [
                  TextSpan(
                    text: 'Beauty ',
                    style: TextStyle(
                      color: Color(0xFF44FF88),
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  TextSpan(
                    text: 'Timer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2,
                    ),
                  ),
                ]),
              ),
              Text(
                subText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () => _showSettingsSheet(context, provider),
            icon: const Icon(Icons.tune, color: Color(0xFFFFD700), size: 26),
            tooltip: '設定',
          ),
        ],
      ),
    );
  }

  // ─── 次の読み上げ + 動作中アラート変更 ──────────
  Widget _buildNextAnnouncement(TimerProvider provider) {
    final isActive = provider.isRunning || provider.isPaused;
    if (!isActive) return const SizedBox(height: 8);

    final isCountDown = provider.settings.mode == TimerMode.countDown;
    final showCountUpRemaining = !isCountDown &&
        provider.settings.countUpLimitSeconds > 0;
    // カウントダウンも残りアラートを表示
    final showRemainingAlerts = isCountDown
        ? provider.settings.remainingAlerts.isNotEmpty
        : showCountUpRemaining;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF44FF88).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 経過時間アラート行 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.arrow_upward, color: Color(0xFF44FF88), size: 14),
                const SizedBox(width: 4),
                Text('経過時間アラート',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                const SizedBox(width: 6),
                _IntervalBadgeList(
                  intervals: provider.settings.elapsedAlerts,
                  color: const Color(0xFF44FF88),
                  useAbsoluteLabel: true,
                  absolutePrefix: '経過',
                ),
              ]),

            ],
          ),
          // ── 残り時間アラート行（カウントアップ+上限 または カウントダウン）──
          if (showRemainingAlerts) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.arrow_downward, color: Color(0xFFFF4444), size: 14),
                  const SizedBox(width: 4),
                  Text('残り時間アラート',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                  const SizedBox(width: 6),
                  _IntervalBadgeList(
                    intervals: provider.settings.remainingAlerts,
                    color: const Color(0xFFFF4444),
                    emptyLabel: 'なし',
                    useAbsoluteLabel: true,
                    absolutePrefix: '残',
                  ),
                ]),

              ],
            ),
          ],
          const SizedBox(height: 10),
          // ── シークバー（手動で時間を進める/戻す）──
          _SeekBar(provider: provider),
          const SizedBox(height: 8),
          // ── クイック変更バー ──
          _IntervalQuickBar(provider: provider),
        ],
      ),
    );
  }

  // ─── コントロールボタン ──────────────────────────
  Widget _buildControls(BuildContext context, TimerProvider provider) {
    final state = provider.state;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            label: state == TimerState.idle ? 'RESET' : 'STOP',
            icon: state == TimerState.idle ? Icons.refresh : Icons.stop,
            color: const Color(0xFFFF4444),
            onPressed: state == TimerState.idle
                ? () => provider.reset()
                : () => provider.stop(),
          ),
          _MainActionButton(provider: provider),
          _ControlButton(
            label: state == TimerState.paused ? 'RESUME' : 'PAUSE',
            icon: state == TimerState.paused ? Icons.play_arrow : Icons.pause,
            color: const Color(0xFFFFD700),
            onPressed: state == TimerState.running
                ? () => provider.pause()
                : state == TimerState.paused
                    ? () => provider.resume()
                    : null,
          ),
        ],
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, TimerProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _SettingsSheet(provider: provider),
    );
  }
}

// ────────────────────────────────────────────────
//  メインアクションボタン
// ────────────────────────────────────────────────
class _MainActionButton extends StatelessWidget {
  final TimerProvider provider;
  const _MainActionButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final state = provider.state;
    final isIdle = state == TimerState.idle || state == TimerState.finished;
    final isPaused = state == TimerState.paused;

    final color = isPaused ? const Color(0xFFFFD700) : const Color(0xFF44FF88);
    final darkColor = isPaused ? const Color(0xFFCC9900) : const Color(0xFF00CC55);

    return GestureDetector(
      onTap: () {
        if (isIdle) {
          provider.start();
        } else if (state == TimerState.running) {
          provider.pause();
        } else if (isPaused) {
          provider.resume();
        }
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, darkColor],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isIdle || isPaused ? Icons.play_arrow : Icons.pause,
          color: const Color(0xFF0A0E1A),
          size: 44,
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  サブコントロールボタン
// ────────────────────────────────────────────────
class _ControlButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _ControlButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final c = isEnabled ? color : color.withValues(alpha: 0.3);
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.withValues(alpha: 0.12),
              border: Border.all(color: c.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Icon(icon, color: c, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: c,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  アラートバッジリスト（複数表示対応）
// ────────────────────────────────────────────────
class _IntervalBadgeList extends StatelessWidget {
  final List<int> intervals;
  final Color color;
  final String emptyLabel;
  /// true のとき絶対値ラベル（durationLabel形式）
  final bool useAbsoluteLabel;
  /// 絶対値モード時のプレフィックス（「経過」「残」など）
  final String absolutePrefix;

  const _IntervalBadgeList({
    required this.intervals,
    required this.color,
    this.emptyLabel = 'なし',
    this.useAbsoluteLabel = false,
    this.absolutePrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (intervals.isEmpty) {
      return _badge(emptyLabel);
    }
    final sorted = [...intervals];
    if (useAbsoluteLabel) {
      sorted.sort(); // 経過は昇順、残りも昇順（バッジは短く表示するため）
    } else {
      sorted.sort();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sorted
          .map((s) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _badge(
                  '$absolutePrefix${TimerSettings.durationLabel(s)}',
                ),
              ))
          .toList(),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ════════════════════════════════════════════════
//  手動シークバー（時間を進める / 戻す）
// ════════════════════════════════════════════════
class _SeekBar extends StatelessWidget {
  final TimerProvider provider;
  const _SeekBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.fast_rewind,
              size: 12, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(width: 4),
          Text('時間を進める / 戻す',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        // ─ 戻す / 進む ─
        Row(
          children: [
            Expanded(
              child: _seekChip(
                context,
                label: '← 戻す',
                color: const Color(0xFFFFAA44),
                onTap: () => _showSeekDialog(context, forward: false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _seekChip(
                context,
                label: '進む →',
                color: const Color(0xFF44AAFF),
                onTap: () => _showSeekDialog(context, forward: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seekChip(BuildContext context,
      {required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.tune, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  void _showSeekDialog(BuildContext context, {required bool forward}) {
    final hourCtrl = TextEditingController(text: '0');
    final minCtrl  = TextEditingController(text: '0');
    final secCtrl  = TextEditingController(text: '0');
    final color = forward ? const Color(0xFF44AAFF) : const Color(0xFFFFAA44);
    final title = forward ? '時間を進める' : '時間を戻す';
    final icon  = forward ? Icons.fast_forward : Icons.fast_rewind;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              forward ? '指定した時間だけ進めます' : '指定した時間だけ戻します',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _SeekField(ctrl: hourCtrl, label: '時間', color: color),
              _seqSep(),
              _SeekField(ctrl: minCtrl,  label: '分',   color: color),
              _seqSep(),
              _SeekField(ctrl: secCtrl,  label: '秒',   color: color),
            ]),
            const SizedBox(height: 8),
            Text('0:00:00 は何もしません',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style:
                    TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final h = int.tryParse(hourCtrl.text) ?? 0;
              final m = int.tryParse(minCtrl.text)  ?? 0;
              final s = int.tryParse(secCtrl.text)  ?? 0;
              final total = h * 3600 + m * 60 + s;
              if (total > 0) {
                provider.seekBy(forward ? total : -total);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(forward ? '進める' : '戻す',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _seqSep() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(':',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 22,
                fontWeight: FontWeight.w300)),
      );
}

// ────────────────────────────────────────────────
//  シークダイアログ用フィールド
// ────────────────────────────────────────────────
class _SeekField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final Color color;
  const _SeekField(
      {required this.ctrl, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0A0E1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════
//  動作中アラートクイック変更バー（タブ切替 + 複数対応）
// ════════════════════════════════════════════════
class _IntervalQuickBar extends StatefulWidget {
  final TimerProvider provider;
  const _IntervalQuickBar({required this.provider});

  @override
  State<_IntervalQuickBar> createState() => _IntervalQuickBarState();
}

class _IntervalQuickBarState extends State<_IntervalQuickBar> {
  bool _showRemaining = false;

  // 経過アラート用プリセット（絶対値、秒）
  static const _elapsedPresets = [
    ('30秒', 30), ('1分', 60), ('2分', 120),
    ('3分', 180), ('5分', 300), ('10分', 600), ('20分', 1200),
  ];

  // 残り時間アラート用プリセット（絶対値、秒）
  static const _remainingPresets = [
    ('10秒', 10), ('30秒', 30), ('1分', 60),
    ('2分', 120), ('3分', 180), ('5分', 300), ('10分', 600),
  ];

  bool get _canShowRemaining =>
      widget.provider.settings.mode == TimerMode.countUp &&
      widget.provider.settings.countUpLimitSeconds > 0;

  List<int> get _currentList => _showRemaining && _canShowRemaining
      ? widget.provider.settings.remainingAlerts
      : widget.provider.settings.elapsedAlerts;

  List<(String, int)> get _currentPresets =>
      _showRemaining && _canShowRemaining ? _remainingPresets : _elapsedPresets;

  Color get _accentColor =>
      _showRemaining && _canShowRemaining
          ? const Color(0xFFFF4444)
          : const Color(0xFF44FF88);

  void _toggle(int sec) {
    final list = List<int>.from(_currentList);
    if (list.contains(sec)) {
      list.remove(sec);
    } else {
      list.add(sec);
    }
    _applyList(list);
  }

  void _applyList(List<int> list) {
    if (_showRemaining && _canShowRemaining) {
      widget.provider.updateRemainingAlerts(list);
    } else {
      widget.provider.updateElapsedAlerts(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showRemainingTab = _canShowRemaining;
    final accent = _accentColor;
    final current = _currentList;
    final presets = _currentPresets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─ タブ切替 ─
        if (showRemainingTab) ...[
          Row(children: [
            _TabChip(
              label: '▲ 経過',
              selected: !_showRemaining,
              color: const Color(0xFF44FF88),
              onTap: () => setState(() => _showRemaining = false),
            ),
            const SizedBox(width: 8),
            _TabChip(
              label: '▼ 残り',
              selected: _showRemaining,
              color: const Color(0xFFFF4444),
              onTap: () => setState(() => _showRemaining = true),
            ),
            const SizedBox(width: 8),
            Text('タップで追加/削除',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10)),
          ]),
          const SizedBox(height: 8),
        ] else ...[
          Row(children: [
            Text('経過アラート タップで追加/削除',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10)),
          ]),
          const SizedBox(height: 6),
        ],
        // ─ プリセットチップ（複数選択）─
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // カスタム入力チップ
              _buildCustomChip(context, current, accent),
              const SizedBox(width: 6),
              ...presets.map((p) {
                final (label, sec) = p;
                final selected = current.contains(sec);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _toggle(sec),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? accent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? accent
                              : Colors.white.withValues(alpha: 0.15),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: selected
                                  ? accent
                                  : Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        // ─ 現在選択中のサマリー ─
        if (current.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text('設定中: ',
                    style: TextStyle(
                        color: accent.withValues(alpha: 0.6),
                        fontSize: 10)),
                ...(List<int>.from(current)..sort()).map((s) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (_showRemaining && _canShowRemaining)
                                ? '残り${TimerSettings.durationLabel(s)}'
                                : '経過${TimerSettings.durationLabel(s)}',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 3),
                          GestureDetector(
                            onTap: () => _toggle(s),
                            child: Icon(Icons.close,
                                size: 10,
                                color: accent.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomChip(
      BuildContext context, List<int> current, Color accent) {
    return GestureDetector(
      onTap: () => _showCustomDialog(context, accent),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.add, size: 12, color: accent),
          const SizedBox(width: 4),
          Text('カスタム',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12)),
        ]),
      ),
    );
  }

  void _showCustomDialog(BuildContext context, Color accentColor) {
    final minCtrl = TextEditingController(text: '0');
    final secCtrl = TextEditingController(text: '0');
    final isRem = _showRemaining && _canShowRemaining;
    final title = isRem ? '残り時間アラートを追加' : '経過時間アラートを追加';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.timer_outlined, color: accentColor, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child: _DialogField(
                      ctrl: minCtrl, label: '分', accentColor: accentColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(':',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 24)),
              ),
              Expanded(
                  child: _DialogField(
                      ctrl: secCtrl, label: '秒', accentColor: accentColor)),
            ]),
            const SizedBox(height: 8),
            Text('0:00 は追加されません',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final m = int.tryParse(minCtrl.text) ?? 0;
              final s = int.tryParse(secCtrl.text) ?? 0;
              final total = m * 60 + s;
              if (total > 0) {
                final list = List<int>.from(_currentList);
                if (!list.contains(total)) {
                  list.add(total);
                  _applyList(list);
                }
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('追加', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  タブチップ
// ────────────────────────────────────────────────
class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TabChip(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  ダイアログ入力フィールド
// ────────────────────────────────────────────────
class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final Color accentColor;
  const _DialogField(
      {required this.ctrl, required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.4)),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
                color: accentColor, fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.zero),
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
      ],
    );
  }
}

// ════════════════════════════════════════════════
//  設定ボトムシート
// ════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final TimerProvider provider;
  const _SettingsSheet({required this.provider});

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late TimerSettings _settings;

  // カウントダウン時間
  late TextEditingController _cdHourCtrl;
  late TextEditingController _cdMinCtrl;
  late TextEditingController _cdSecCtrl;
  // カウントアップ上限
  late TextEditingController _cuHourCtrl;
  late TextEditingController _cuMinCtrl;
  late TextEditingController _cuSecCtrl;

  @override
  void initState() {
    super.initState();
    _settings = widget.provider.settings.copyWith();

    final cd = _settings.countDownTotalSeconds;
    _cdHourCtrl = TextEditingController(text: '${cd ~/ 3600}');
    _cdMinCtrl  = TextEditingController(text: '${(cd % 3600) ~/ 60}');
    _cdSecCtrl  = TextEditingController(text: '${cd % 60}');

    final cu = _settings.countUpLimitSeconds;
    _cuHourCtrl = TextEditingController(text: '${cu ~/ 3600}');
    _cuMinCtrl  = TextEditingController(text: '${(cu % 3600) ~/ 60}');
    _cuSecCtrl  = TextEditingController(text: '${cu % 60}');
  }

  @override
  void dispose() {
    for (final c in [
      _cdHourCtrl, _cdMinCtrl, _cdSecCtrl,
      _cuHourCtrl, _cuMinCtrl, _cuSecCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _toSec(TextEditingController h, TextEditingController m,
      TextEditingController s) {
    return (int.tryParse(h.text) ?? 0) * 3600 +
        (int.tryParse(m.text) ?? 0) * 60 +
        (int.tryParse(s.text) ?? 0);
  }

  void _apply() {
    final isActive = widget.provider.isRunning || widget.provider.isPaused;

    if (isActive) {
      // 動作中: アラートリストのみ即時適用
      widget.provider.updateSettings(_settings.copyWith(
        elapsedAlerts: _settings.elapsedAlerts,
        remainingAlerts: _settings.remainingAlerts,
      ));
    } else {
      final cdTotal = _toSec(_cdHourCtrl, _cdMinCtrl, _cdSecCtrl)
          .clamp(5, 99 * 3600);
      final cuLimit = _toSec(_cuHourCtrl, _cuMinCtrl, _cuSecCtrl)
          .clamp(0, 99 * 3600);
      widget.provider.updateSettings(_settings.copyWith(
        countDownTotalSeconds: cdTotal,
        countUpLimitSeconds: cuLimit,
      ));
    }
    Navigator.pop(context);
  }

  // ─── 経過アラートリスト編集 ───────────────────────
  void _toggleElapsed(int sec) {
    final list = List<int>.from(_settings.elapsedAlerts);
    if (list.contains(sec)) {
      list.remove(sec);
    } else {
      list.add(sec);
    }
    setState(() {
      _settings = _settings.copyWith(elapsedAlerts: list);
    });
  }

  void _toggleRemaining(int sec) {
    final list = List<int>.from(_settings.remainingAlerts);
    if (list.contains(sec)) {
      list.remove(sec);
    } else {
      list.add(sec);
    }
    setState(() {
      _settings = _settings.copyWith(remainingAlerts: list);
    });
  }

  void _addCustomElapsed(int sec) {
    if (sec <= 0) return;
    final list = List<int>.from(_settings.elapsedAlerts);
    if (!list.contains(sec)) list.add(sec);
    setState(() => _settings = _settings.copyWith(elapsedAlerts: list));
  }

  void _addCustomRemaining(int sec) {
    if (sec <= 0) return;
    final list = List<int>.from(_settings.remainingAlerts);
    if (!list.contains(sec)) list.add(sec);
    setState(() => _settings = _settings.copyWith(remainingAlerts: list));
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.provider.isRunning || widget.provider.isPaused;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111827),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ハンドル
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    // タイトル + 動作中バナー
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('⚙  設定',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        if (isActive) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_circle_outline,
                                    color: Color(0xFFFFD700), size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'タイマー動作中 — アラート設定のみ変更可',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.9),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── モード選択（動作中はロック）──
                    _buildLockedSection(
                      isActive,
                      title: 'タイマーモード',
                      child: Row(children: [
                        _ModeChip(
                          label: '▲ カウントアップ',
                          selected: _settings.mode == TimerMode.countUp,
                          activeColor: const Color(0xFF44FF88),
                          onTap: locked(isActive, () => setState(() => _settings =
                              _settings.copyWith(mode: TimerMode.countUp))),
                        ),
                        const SizedBox(width: 12),
                        _ModeChip(
                          label: '▼ カウントダウン',
                          selected: _settings.mode == TimerMode.countDown,
                          activeColor: const Color(0xFFFF4444),
                          onTap: locked(isActive, () => setState(() => _settings =
                              _settings.copyWith(mode: TimerMode.countDown))),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // ── カウントダウン時間（動作中はロック）──
                    if (_settings.mode == TimerMode.countDown) ...[
                      _buildLockedSection(
                        isActive,
                        title: 'カウントダウン時間',
                        child: Column(children: [
                          _TimeInputRow(
                            hourCtrl: _cdHourCtrl,
                            minCtrl: _cdMinCtrl,
                            secCtrl: _cdSecCtrl,
                            accentColor: const Color(0xFFFF4444),
                            showHours: true,
                          ),
                          const SizedBox(height: 6),
                          _QuickTimeChips(
                            accentColor: const Color(0xFFFF4444),
                            options: const [
                              ('1分', 0, 1, 0), ('3分', 0, 3, 0), ('5分', 0, 5, 0),
                              ('10分', 0, 10, 0), ('15分', 0, 15, 0),
                              ('20分', 0, 20, 0), ('30分', 0, 30, 0),
                              ('45分', 0, 45, 0), ('1時間', 1, 0, 0),
                              ('1.5時間', 1, 30, 0), ('2時間', 2, 0, 0),
                            ],
                            onSelect: locked(isActive, (h, m, s) {
                              setState(() {
                                _cdHourCtrl.text = '$h';
                                _cdMinCtrl.text = '$m';
                                _cdSecCtrl.text = '$s';
                              });
                            }),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── カウントアップ上限（動作中はロック）──
                    if (_settings.mode == TimerMode.countUp) ...[
                      _buildLockedSection(
                        isActive,
                        title: 'カウントアップ上限時間',
                        subtitle: '0の場合は無制限',
                        child: Column(children: [
                          _TimeInputRow(
                            hourCtrl: _cuHourCtrl,
                            minCtrl: _cuMinCtrl,
                            secCtrl: _cuSecCtrl,
                            accentColor: const Color(0xFF44FF88),
                            showHours: true,
                          ),
                          const SizedBox(height: 6),
                          _QuickTimeChips(
                            accentColor: const Color(0xFF44FF88),
                            options: const [
                              ('無制限', 0, 0, 0), ('5分', 0, 5, 0),
                              ('10分', 0, 10, 0), ('15分', 0, 15, 0),
                              ('20分', 0, 20, 0), ('30分', 0, 30, 0),
                              ('45分', 0, 45, 0), ('1時間', 1, 0, 0),
                              ('2時間', 2, 0, 0),
                            ],
                            onSelect: locked(isActive, (h, m, s) {
                              setState(() {
                                _cuHourCtrl.text = '$h';
                                _cuMinCtrl.text = '$m';
                                _cuSecCtrl.text = '$s';
                              });
                            }),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // ── 経過時間アラート（絶対値指定）──
                    _buildElapsedAlertSection(
                      accentColor: const Color(0xFF44FF88),
                      selected: _settings.elapsedAlerts,
                      onToggle: _toggleElapsed,
                      onAddCustom: _addCustomElapsed,
                    ),
                    const SizedBox(height: 24),

                    // ── 残り時間アラート（残り○秒/分になったら読む）──
                    // カウントアップ: 上限設定時のみ表示
                    // カウントダウン: 常に表示
                    Builder(builder: (_) {
                      if (_settings.mode == TimerMode.countUp) {
                        final cuLimitNow = _toSec(_cuHourCtrl, _cuMinCtrl, _cuSecCtrl);
                        if (cuLimitNow <= 0 && !isActive) {
                          return const SizedBox.shrink();
                        }
                      }
                      return Column(
                        children: [
                          _buildRemainingAlertSection(
                            accentColor: const Color(0xFFFF4444),
                            selected: _settings.remainingAlerts,
                            onToggle: _toggleRemaining,
                            onAddCustom: _addCustomRemaining,
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    }),

                    // ── 読み上げ内容サマリー ──
                    _AnnounceSummaryCard(settings: _settings),
                    const SizedBox(height: 24),

                    // ── 適用ボタン ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF44FF88),
                          foregroundColor: const Color(0xFF0A0E1A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('設定を適用',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 経過時間アラートセクション（絶対値指定）───────────
  Widget _buildElapsedAlertSection({
    required Color accentColor,
    required List<int> selected,
    required void Function(int) onToggle,
    required void Function(int) onAddCustom,
  }) {
    // プリセット: 経過時間の絶対値（秒）
    const presets = [
      ('30秒', 30), ('1分', 60), ('2分', 120), ('3分', 180),
      ('5分', 300), ('10分', 600), ('15分', 900), ('20分', 1200), ('30分', 1800),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.arrow_upward, color: Color(0xFF44FF88), size: 14),
          const SizedBox(width: 6),
          _sectionTitle('経過時間アラート'),
        ]),
        const SizedBox(height: 3),
        Text('経過時間がこの値になったときに読み上げる 「○○分経過」',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        const SizedBox(height: 10),
        // プリセットチップ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // カスタム追加ボタン
            GestureDetector(
              onTap: () => _showCustomElapsedAlertDialog(
                  context, accentColor, onAddCustom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 13, color: accentColor),
                  const SizedBox(width: 4),
                  Text('カスタム',
                      style: TextStyle(color: accentColor, fontSize: 12)),
                ]),
              ),
            ),
            ...presets.map((p) {
              final (label, sec) = p;
              final isSelected = selected.contains(sec);
              return GestureDetector(
                onTap: () => onToggle(sec),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.18)
                        : const Color(0xFF1A1F30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isSelected) ...[
                      Icon(Icons.check, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                    ],
                    Text(label,
                        style: TextStyle(
                            color: isSelected
                                ? accentColor
                                : Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ]),
                ),
              );
            }),
          ],
        ),
        // 現在の選択サマリー（昇順ソート）
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (List<int>.from(selected)..sort())
                .map((s) => GestureDetector(
                      onTap: () => onToggle(s),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('経過${TimerSettings.durationLabel(s)}',
                              style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Icon(Icons.close,
                              size: 12,
                              color: accentColor.withValues(alpha: 0.6)),
                        ]),
                      ),
                    ))
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text('  読み上げなし',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  void _showCustomElapsedAlertDialog(BuildContext context,
      Color accentColor, void Function(int) onAdd) {
    final minCtrl = TextEditingController(text: '0');
    final secCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.timer_outlined, color: accentColor, size: 20),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('経過時間アラートを追加',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('経過時間がこの値になったときに読み上げます',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _DialogField(
                      ctrl: minCtrl, label: '分', accentColor: accentColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(':',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 24)),
              ),
              Expanded(
                  child: _DialogField(
                      ctrl: secCtrl, label: '秒', accentColor: accentColor)),
            ]),
            const SizedBox(height: 8),
            Text('0:00 は追加されません',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final m = int.tryParse(minCtrl.text) ?? 0;
              final s = int.tryParse(secCtrl.text) ?? 0;
              onAdd(m * 60 + s);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('追加',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── 残り時間アラートセクション（絶対値指定）───────────
  Widget _buildRemainingAlertSection({
    required Color accentColor,
    required List<int> selected,
    required void Function(int) onToggle,
    required void Function(int) onAddCustom,
  }) {
    // プリセット: 残り時間の絶対値（秒）
    const presets = [
      ('残り10秒', 10), ('残り20秒', 20), ('残り30秒', 30),
      ('残り1分', 60), ('残り2分', 120), ('残り3分', 180),
      ('残り5分', 300), ('残り10分', 600), ('残り15分', 900),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.arrow_downward, color: Color(0xFFFF4444), size: 14),
          const SizedBox(width: 6),
          _sectionTitle('残り時間アラート'),
        ]),
        const SizedBox(height: 3),
        Text('残り時間がこの値になったときに読み上げる 「残り時間○分」',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        const SizedBox(height: 10),
        // プリセットチップ
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // カスタム追加ボタン
            GestureDetector(
              onTap: () => _showCustomRemainingAlertDialog(
                  context, accentColor, onAddCustom),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 13, color: accentColor),
                  const SizedBox(width: 4),
                  Text('カスタム',
                      style: TextStyle(color: accentColor, fontSize: 12)),
                ]),
              ),
            ),
            ...presets.map((p) {
              final (label, sec) = p;
              final isSelected = selected.contains(sec);
              return GestureDetector(
                onTap: () => onToggle(sec),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.18)
                        : const Color(0xFF1A1F30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : Colors.white.withValues(alpha: 0.15),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isSelected) ...[  
                      Icon(Icons.check, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                    ],
                    Text(label,
                        style: TextStyle(
                            color: isSelected
                                ? accentColor
                                : Colors.white.withValues(alpha: 0.55),
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ]),
                ),
              );
            }),
          ],
        ),
        // 現在の選択サマリー（降順ソート）
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (List<int>.from(selected)..sort((a, b) => b.compareTo(a)))
                .map((s) => GestureDetector(
                      onTap: () => onToggle(s),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('残り${TimerSettings.durationLabel(s)}',
                              style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Icon(Icons.close,
                              size: 12,
                              color: accentColor.withValues(alpha: 0.6)),
                        ]),
                      ),
                    ))
                .toList(),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Text('  読み上げなし',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ],
    );
  }

  void _showCustomRemainingAlertDialog(BuildContext context,
      Color accentColor, void Function(int) onAdd) {
    final minCtrl = TextEditingController(text: '0');
    final secCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.timer_outlined, color: accentColor, size: 20),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('残り時間アラートを追加',
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('残り時間がこの値になったときに読み上げます',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _DialogField(
                      ctrl: minCtrl, label: '分', accentColor: accentColor)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(':',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 24)),
              ),
              Expanded(
                  child: _DialogField(
                      ctrl: secCtrl, label: '秒', accentColor: accentColor)),
            ]),
            const SizedBox(height: 8),
            Text('0:00 は追加されません',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              final m = int.tryParse(minCtrl.text) ?? 0;
              final s = int.tryParse(secCtrl.text) ?? 0;
              onAdd(m * 60 + s);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: const Color(0xFF0A0E1A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('追加',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── ロック付きセクションラッパー ──────────────────
  Widget _buildLockedSection(
    bool locked, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _sectionTitle(title),
          if (locked) ...[
            const SizedBox(width: 8),
            Icon(Icons.lock_outline,
                size: 13, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ],
        const SizedBox(height: 10),
        Opacity(opacity: locked ? 0.4 : 1.0, child: child),
      ],
    );
  }

  Widget _sectionTitle(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }
}

// ─── locked ヘルパー（動作中は無効化）──────────────
T locked<T>(bool isLocked, T callback) =>
    isLocked ? (callback is Function ? (() {}) as T : callback) : callback;

// ────────────────────────────────────────────────
//  時間入力行
// ────────────────────────────────────────────────
class _TimeInputRow extends StatelessWidget {
  final TextEditingController? hourCtrl;
  final TextEditingController minCtrl;
  final TextEditingController secCtrl;
  final Color accentColor;
  final bool showHours;

  const _TimeInputRow({
    required this.hourCtrl,
    required this.minCtrl,
    required this.secCtrl,
    required this.accentColor,
    required this.showHours,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showHours && hourCtrl != null) ...[
          _TimeField(
              ctrl: hourCtrl!, label: '時', accentColor: accentColor, max: 99),
          _separator(),
        ],
        _TimeField(ctrl: minCtrl, label: '分', accentColor: accentColor, max: 59),
        _separator(),
        _TimeField(ctrl: secCtrl, label: '秒', accentColor: accentColor, max: 59),
      ],
    );
  }

  Widget _separator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(':',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 24,
              fontWeight: FontWeight.w300)),
    );
  }
}

class _TimeField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final Color accentColor;
  final int max;

  const _TimeField({
    required this.ctrl,
    required this.label,
    required this.accentColor,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.35)),
            ),
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  クイック選択チップ
// ────────────────────────────────────────────────
class _QuickTimeChips extends StatelessWidget {
  final Color accentColor;
  final List<(String, int, int, int)> options;
  final dynamic onSelect; // Function(int h, int m, int s) or locked no-op

  const _QuickTimeChips({
    required this.accentColor,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((opt) {
        final (label, h, m, s) = opt;
        return GestureDetector(
          onTap: () {
            if (onSelect is Function) onSelect(h, m, s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.3)),
            ),
            child: Text(label,
                style: TextStyle(
                    color: accentColor.withValues(alpha: 0.9), fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }
}

// ────────────────────────────────────────────────
//  モード選択チップ
// ────────────────────────────────────────────────
class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.15)
              : const Color(0xFF1A1F30),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : Colors.white.withValues(alpha: 0.15),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ────────────────────────────────────────────────
//  読み上げ内容サマリーカード
// ────────────────────────────────────────────────
class _AnnounceSummaryCard extends StatelessWidget {
  final TimerSettings settings;
  const _AnnounceSummaryCard({required this.settings});

  @override
  Widget build(BuildContext context) {
    final isCountUp = settings.mode == TimerMode.countUp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F30),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.record_voice_over,
                color: Color(0xFFFFD700), size: 16),
            SizedBox(width: 8),
            Text('読み上げ内容',
                style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          _row('開始時', '「作業はじめ」'),
          _row('終了時', '「作業やめ」'),
          if (isCountUp) ...[
            if (settings.elapsedAlerts.isNotEmpty)
              _row(
                '経過アラート',
                settings.elapsedAlertsLabel,
              )
            else
              _row('経過読み上げ', 'なし'),
            if (settings.countUpLimitSeconds > 0) ...[
              if (settings.remainingAlerts.isNotEmpty)
                _row(
                  '残り時間アラート',
                  settings.remainingAlertsLabel,
                )
              else
                _row('残り時間読み上げ', 'なし'),
              _row('上限', settings.countUpLimitLabel),
            ] else
              _row('上限', '無制限'),
          ] else ...[
            if (settings.elapsedAlerts.isNotEmpty)
              _row(
                '経過アラート',
                settings.elapsedAlertsLabel,
              )
            else
              _row('経過読み上げ', 'なし'),
            if (settings.remainingAlerts.isNotEmpty)
              _row('残り時間アラート', settings.remainingAlertsLabel),
            _row('設定時間', settings.countDownLabel),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(children: [
        Text('$label : ',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
        Flexible(
          child: Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
