import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/supabase_service.dart';

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
final cmsLessonItemsProvider =
    FutureProvider.autoDispose.family<List<LessonItem>, String>((ref, lessonId) {
  return ref.watch(contentRepositoryProvider).fetchLessonItems(lessonId);
});

/// [ContentRepository] intentionally only exposes create/delete for lessons
/// (unlike units and items, which also support update). Editing a lesson's
/// title/sort_order is plain CRUD scoped entirely to the CMS, so that one
/// mutation lives here instead — same `lessons` table, RLS still applies.
Future<void> updateLesson(String id, Map<String, dynamic> changes) async {
  await SupabaseService.client.from('lessons').update(changes).eq('id', id);
}
