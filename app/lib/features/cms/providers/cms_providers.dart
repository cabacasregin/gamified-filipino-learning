import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';

/// All curriculum units, teacher-editable. After any create/update/delete,
/// call `ref.invalidate(cmsUnitsProvider)` to refresh the list.
final cmsUnitsProvider = FutureProvider.autoDispose<List<CurriculumUnit>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchUnits();
});

/// Lessons within one unit. Invalidate with the same [unitId] after a
/// mutation to refresh.
final cmsLessonsProvider = FutureProvider.autoDispose.family<List<Lesson>, String>((ref, unitId) {
  return ref.watch(contentRepositoryProvider).fetchLessons(unitId);
});

/// Items within one lesson. Invalidate with the same [lessonId] after a
/// mutation to refresh.
final cmsLessonItemsProvider = FutureProvider.autoDispose.family<List<LessonItem>, String>((
  ref,
  lessonId,
) {
  return ref.watch(contentRepositoryProvider).fetchLessonItems(lessonId);
});
