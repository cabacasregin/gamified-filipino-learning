import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Aggregated progress data for teacher/parent dashboards. RLS restricts
/// rows to students the caller is allowed to see (their class, or their
/// linked children).
class ProgressRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Students visible to the current parent (id + display name).
  Future<List<Map<String, dynamic>>> fetchChildrenForParent() async {
    final links = await _client.from('parent_children').select('student_id');
    final ids = List<Map<String, dynamic>>.from(links)
        .map((r) => r['student_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final profiles = await _client.from('profiles').select('id, full_name').inFilter('id', ids);
    return List<Map<String, dynamic>>.from(profiles);
  }

  /// Students visible to the current teacher (their classes), id + name.
  Future<List<Map<String, dynamic>>> fetchStudentsForTeacher() async {
    final links = await _client.from('class_students').select('student_id');
    final ids = List<Map<String, dynamic>>.from(links)
        .map((r) => r['student_id'] as String)
        .toList();
    if (ids.isEmpty) return [];
    final profiles = await _client.from('profiles').select('id, full_name').inFilter('id', ids);
    return List<Map<String, dynamic>>.from(profiles);
  }

  /// Per-unit mastery for one student: attempts, correct count, accuracy.
  Future<List<Map<String, dynamic>>> fetchUnitMastery(String studentId) async {
    final rows = await _client.rpc('student_unit_mastery', params: {'p_student_id': studentId});
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<int> fetchPointsBalance(String studentId) async {
    final row = await _client
        .from('student_points_balance')
        .select('balance')
        .eq('student_id', studentId)
        .maybeSingle();
    return (row?['balance'] as int?) ?? 0;
  }

  /// Points earned per day for the last [days] days, for a simple trend
  /// chart on the dashboards. Returns `{'points': ..., 'created_at': ...}`
  /// rows — `points_transactions`' actual column is `delta`, renamed here
  /// so callers don't need to know that storage detail.
  Future<List<Map<String, dynamic>>> fetchDailyPoints(String studentId, {int days = 14}) async {
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await _client
        .from('points_transactions')
        .select('delta, created_at')
        .eq('student_id', studentId)
        .gte('created_at', since)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows)
        .map((r) => {'points': r['delta'], 'created_at': r['created_at']})
        .toList();
  }
}
