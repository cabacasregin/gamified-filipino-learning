import '../models/curriculum_models.dart';

/// Decides whether a speech-to-text transcript counts as a correct spoken
/// answer for a [LessonItem].
///
/// On-device speech recognition rarely has a proper Filipino language
/// model, so a learner saying "dalawa" might be transcribed as "the lawa",
/// "da lawa", etc. Rather than requiring an exact match (which would make
/// the assessment nearly unusable) we: normalize case/punctuation/spacing,
/// accept the curated `accepted_variants` list from the content team, and
/// fall back to a lightweight edit-distance check so minor mis-hearings
/// still pass. This is a pragmatic trade-off documented for whoever swaps
/// in a cloud pronunciation-assessment API later (see `SpeechEvaluator`
/// interface note in speech_recognition_service.dart).
class AnswerMatcher {
  static const double _fuzzyThreshold = 0.75;

  static bool isCorrect(String transcript, LessonItem item) {
    final candidates = <String>{
      item.filipinoText,
      ...item.acceptedVariants,
    };
    final normalizedTranscript = _normalize(transcript);
    if (normalizedTranscript.isEmpty) return false;

    for (final candidate in candidates) {
      final normalizedCandidate = _normalize(candidate);
      if (normalizedCandidate.isEmpty) continue;
      if (normalizedTranscript == normalizedCandidate) return true;
      if (normalizedTranscript.contains(normalizedCandidate) ||
          normalizedCandidate.contains(normalizedTranscript)) {
        return true;
      }
      if (_similarity(normalizedTranscript, normalizedCandidate) >= _fuzzyThreshold) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-zñ0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '');
  }

  /// 1.0 = identical, 0.0 = completely different. Based on Levenshtein
  /// distance normalized by the longer string's length.
  static double _similarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final distance = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (distance / maxLen);
  }

  static int _levenshtein(String a, String b) {
    final la = a.length;
    final lb = b.length;
    if (la == 0) return lb;
    if (lb == 0) return la;

    var previousRow = List<int>.generate(lb + 1, (i) => i);
    for (var i = 0; i < la; i++) {
      final currentRow = List<int>.filled(lb + 1, 0);
      currentRow[0] = i + 1;
      for (var j = 0; j < lb; j++) {
        final deletionCost = previousRow[j + 1] + 1;
        final insertionCost = currentRow[j] + 1;
        final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
        currentRow[j + 1] = [deletionCost, insertionCost, substitutionCost].reduce(
          (v, e) => v < e ? v : e,
        );
      }
      previousRow = currentRow;
    }
    return previousRow[lb];
  }
}
