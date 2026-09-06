import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text` (on-device speech recognition) for the assessment
/// flow. We ask for a Filipino locale when the platform offers one; many
/// devices don't ship a `fil-PH` speech model, so we fall back to the
/// device default (usually `en-US`) and rely on [AnswerMatcher]'s fuzzy /
/// phonetic-variant matching to absorb the accent mismatch — see
/// `core/utils/answer_matcher.dart` for why that's an acceptable trade-off
/// versus requiring a cloud speech API.
class SpeechRecognitionService {
  final SpeechToText _stt = SpeechToText();
  bool _available = false;
  String? _filipinoLocaleId;

  Future<bool> init() async {
    _available = await _stt.initialize(onError: (_) {}, onStatus: (_) {});
    if (_available) {
      final locales = await _stt.locales();
      final match = locales.where((l) => l.localeId.toLowerCase().startsWith('fil')).toList();
      if (match.isNotEmpty) _filipinoLocaleId = match.first.localeId;
    }
    return _available;
  }

  bool get isAvailable => _available;
  bool get hasFilipinoLocale => _filipinoLocaleId != null;

  /// Listens for a single short utterance and returns the best-guess
  /// transcript, or null if nothing was recognized before [timeout].
  Future<String?> listenOnce({Duration timeout = const Duration(seconds: 6)}) async {
    if (!_available) {
      final ok = await init();
      if (!ok) return null;
    }

    final completer = Completer<String?>();

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.confirmation,
        partialResults: true,
        localeId: _filipinoLocaleId,
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
      ),
    );

    final result = await completer.future.timeout(
      timeout + const Duration(seconds: 2),
      onTimeout: () => null,
    );
    await _stt.stop();
    return (result == null || result.trim().isEmpty) ? null : result;
  }

  Future<void> cancel() => _stt.cancel();
}
