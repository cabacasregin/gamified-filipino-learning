import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/progress_models.dart';
import 'supabase_service.dart';

/// All point mutations go through Postgres RPCs (`record_learn_completion`,
/// `record_assessment_attempt`) rather than direct table writes, so the
/// server is the single source of truth for the point economy and a
/// tampered client can't grant itself arbitrary points.
class PointsRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<int> fetchBalance(String studentId) async {
    final row = await _client
        .from('student_points_balance')
        .select('balance')
        .eq('student_id', studentId)
        .maybeSingle();
    return (row?['balance'] as int?) ?? 0;
  }

  Stream<int> watchBalance(String studentId) {
    return _client
        .from('points_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .map((rows) => rows.fold<int>(0, (sum, r) => sum + (r['delta'] as int)));
  }

  /// Returns the points actually awarded (0 if already completed before).
  ///
  /// `record_learn_completion` is declared `returns table(already_completed
  /// boolean, points_awarded integer)` in Postgres, which PostgREST (and so
  /// supabase-dart) always surfaces as a list of row-objects — one row in
  /// this case — never a bare scalar, even though the function logically
  /// returns a single value per call.
  Future<int> recordLearnCompletion(String lessonItemId) async {
    final result = await _client.rpc(
      'record_learn_completion',
      params: {'p_lesson_item_id': lessonItemId},
    );
    return _firstRowIntField(result, 'points_awarded');
  }

  /// Records a spoken-assessment attempt and returns the SERVER's verdict:
  /// [AssessmentResult.isCorrect] (recomputed server-side against
  /// `filipino_text`/`accepted_variants` — exact match only, no fuzzy
  /// matching) and [AssessmentResult.pointsAwarded] (0 if incorrect, or if
  /// points for this item were already earned previously).
  ///
  /// [clientGuessedCorrect] (from [AnswerMatcher]'s fuzzier, edit-distance
  /// -tolerant matching) is passed along for the server's audit trail only
  /// — it is NOT trusted for scoring, and callers must branch UI feedback
  /// on the returned [AssessmentResult.isCorrect], not on their own guess,
  /// so what the learner sees always matches what's recorded and rewarded.
  Future<AssessmentResult> recordAssessmentAttempt({
    required String lessonItemId,
    required String transcript,
    required bool clientGuessedCorrect,
  }) async {
    final result = await _client.rpc(
      'record_assessment_attempt',
      params: {
        'p_lesson_item_id': lessonItemId,
        'p_transcript': transcript,
        'p_is_correct': clientGuessedCorrect,
      },
    );
    if (result is List && result.isNotEmpty && result.first is Map) {
      final row = result.first as Map;
      return AssessmentResult(
        isCorrect: row['is_correct'] as bool? ?? false,
        pointsAwarded: row['points_awarded'] as int? ?? 0,
      );
    }
    // RPC call failed before returning (caller already wraps this in
    // try/catch for the offline case) or returned an unexpected shape —
    // fall back to the client's own guess so the UI still has something
    // reasonable to show, with zero points since nothing was recorded.
    return AssessmentResult(isCorrect: clientGuessedCorrect, pointsAwarded: 0);
  }

  int _firstRowIntField(dynamic result, String field) {
    if (result is List && result.isNotEmpty) {
      final row = result.first;
      if (row is Map && row[field] is int) return row[field] as int;
    }
    return 0;
  }

  Future<List<AssessmentAttempt>> fetchAttemptsForStudent(String studentId) async {
    final rows = await _client
        .from('assessment_attempts')
        .select()
        .eq('student_id', studentId)
        .order('attempted_at');
    return rows.map((r) => AssessmentAttempt.fromMap(r)).toList();
  }
}
