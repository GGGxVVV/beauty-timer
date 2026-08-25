import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _flutterTts = FlutterTts();
      await _applyVoice();
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('TTS init error: $e');
    }
  }

  Future<void> _applyVoice() async {
    final tts = _flutterTts;
    if (tts == null) return;

    await tts.setLanguage('ja-JP');
    await tts.setVolume(1.0);

    // 自然な話し方: やや落ち着いたペース・自然なピッチ
    await tts.setSpeechRate(0.82);
    await tts.setPitch(1.05);

    // 日本語女性音声を優先して選択
    try {
      final voices = await tts.getVoices;
      if (voices != null) {
        final vList = voices as List;
        // 優先順: kyoko / haruka / mizuki / female / woman 含む日本語音声
        final voice = vList.firstWhere(
              (v) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                return locale.contains('ja') && name.contains('kyoko');
              },
              orElse: () => null,
            ) ??
            vList.firstWhere(
              (v) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                return locale.contains('ja') && name.contains('haruka');
              },
              orElse: () => null,
            ) ??
            vList.firstWhere(
              (v) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                return locale.contains('ja') && name.contains('mizuki');
              },
              orElse: () => null,
            ) ??
            vList.firstWhere(
              (v) {
                final name = (v['name'] ?? '').toString().toLowerCase();
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                return locale.contains('ja') &&
                    (name.contains('female') || name.contains('woman'));
              },
              orElse: () => null,
            ) ??
            // フォールバック: ja-JP の最初の音声
            vList.firstWhere(
              (v) {
                final locale = (v['locale'] ?? '').toString().toLowerCase();
                return locale.contains('ja');
              },
              orElse: () => null,
            );

        if (voice != null) {
          await tts.setVoice({
            'name': voice['name'],
            'locale': voice['locale'],
          });
        }
      }
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('TTS speak error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts?.stop();
    } catch (e) {
      if (kDebugMode) debugPrint('TTS stop error: $e');
    }
  }

  // ─── 読み上げ文言（自然な話しかけ調）────────────────

  Future<void> announceStart() async => speak('作業はじめ');
  Future<void> announceStop() async => speak('作業やめ');

  /// カウントアップ: ○分経過
  Future<void> announceElapsedMinutes(int minutes) async =>
      speak('$minutes分経過');

  /// カウントアップ: ○秒経過（1分未満）
  Future<void> announceElapsedSeconds(int seconds) async =>
      speak('$seconds秒経過');

  /// 残り時間: 残り○分
  Future<void> announceRemainingMinutes(int minutes) async =>
      speak('残り時間$minutes分');

  /// 残り時間: 残り○秒（1分未満）
  Future<void> announceRemainingSeconds(int seconds) async =>
      speak('残り時間$seconds秒');

  void dispose() {
    _flutterTts?.stop();
  }
}
