import 'package:flutter_tts/flutter_tts.dart';

/// Speaks Filipino text aloud for "correct pronunciation" playback. We
/// synthesize audio on-device via TTS rather than shipping recorded audio
/// files for every vocabulary item — it scales to new content instantly
/// and needs no asset pipeline, at the cost of sounding synthetic rather
/// than human. `fil-PH` is requested first; devices without a Filipino
/// voice installed fall back to a slowed-down default voice, which is
/// still close enough for most Filipino words given their phonetic
/// (read-as-written) spelling.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _hasFilipinoVoice = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final languages = await _tts.getLanguages;
      _hasFilipinoVoice =
          languages is List && languages.any((l) => l.toString().toLowerCase().startsWith('fil'));
    } catch (_) {
      _hasFilipinoVoice = false;
    }
    await _tts.setLanguage(_hasFilipinoVoice ? 'fil-PH' : 'en-US');
    // Filipino is read phonetically; slowing down a non-Filipino voice
    // reduces mispronunciation of vowel sounds when no fil-PH voice exists.
    await _tts.setSpeechRate(_hasFilipinoVoice ? 0.45 : 0.35);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();

  bool get hasFilipinoVoice => _hasFilipinoVoice;
}
