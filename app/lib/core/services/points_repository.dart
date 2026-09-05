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
        .map((rows) => rows.fold<int>(0, (sum, r) => sum + (r['points'] as int)));
  }

  /// Returns the points actually awarded (0 if already completed before).
  Future<int> recordLearnCompletion(String lessonItemId) async {
    final result = await _client.rpc(
      'record_learn_completion',
      params: {'p_lesson_item_id': lessonItemId},
    );
    return (result as int?) ?? 0;
  }

  /// Records a spoken-assessment attempt and returns the points awarded
  /// (0 if incorrect, or if points for this item were already earned this
  /// session).
  Future<int> recordAssessmentAttempt({
    required String lessonItemId,
    required String transcript,
    required bool isCorrect,
  }) async {
    final result = await _client.rpc(
      'record_assessment_attempt',
      params: {
        'p_lesson_item_id': lessonItemId,
        'p_transcript': transcript,
        'p_is_correct': isCorrect,
      },
    );
    return (result as int?) ?? 0;
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
