import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';

/// Students visible to the signed-in teacher: `[{id, full_name}, ...]`.
final studentsForTeacherProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(progressRepositoryProvider).fetchStudentsForTeacher();
});

/// Children visible to the signed-in parent: `[{id, full_name}, ...]`.
final childrenForParentProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(progressRepositoryProvider).fetchChildrenForParent();
});

/// Per-unit mastery rows for one student:
/// `{unit_id, unit_title, total_items, attempted_count, correct_count, accuracy}`.
final unitMasteryProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, studentId) {
  return ref.watch(progressRepositoryProvider).fetchUnitMastery(studentId);
});

/// Raw points-transaction rows for the last 14 days for one student, used
/// to build the points-over-time trend chart.
final dailyPointsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, studentId) {
  return ref.watch(progressRepositoryProvider).fetchDailyPoints(studentId, days: 14);
});
