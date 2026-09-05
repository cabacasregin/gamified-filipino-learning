import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/curriculum_models.dart';
import 'supabase_service.dart';

/// Read access for every learner (curriculum is public content), plus
/// write access for teachers (enforced server-side by RLS — a student
/// calling `createUnit` etc. simply gets a Postgres permission error).
class ContentRepository {
  final SupabaseClient _client = SupabaseService.client;

  Future<List<CurriculumUnit>> fetchUnits() async {
    final rows = await _client.from('curriculum_units').select().order('sort_order');
    return rows.map((r) => CurriculumUnit.fromMap(r)).toList();
  }

  Future<List<Lesson>> fetchLessons(String unitId) async {
    final rows = await _client
        .from('lessons')
        .select()
        .eq('unit_id', unitId)
        .order('sort_order');
    return rows.map((r) => Lesson.fromMap(r)).toList();
  }

  Future<List<LessonItem>> fetchLessonItems(String lessonId) async {
    final rows = await _client
        .from('lesson_items')
        .select()
        .eq('lesson_id', lessonId)
        .order('sort_order');
    return rows.map((r) => LessonItem.fromMap(r)).toList();
  }

  /// Convenience for the student "learn"/"assessment" flows, which operate
  /// per-unit rather than per-lesson: flattens every item across a unit's
  /// lessons, in curriculum order.
  Future<List<LessonItem>> fetchUnitItems(String unitId) async {
    final lessons = await fetchLessons(unitId);
    final items = <LessonItem>[];
    for (final lesson in lessons) {
      items.addAll(await fetchLessonItems(lesson.id));
    }
    return items;
  }

  // --- Teacher CMS mutations ---

  Future<CurriculumUnit> createUnit(CurriculumUnit unit) async {
    final columns = CurriculumUnit.mapToColumns(
      unit.toMap(),
      newSlug: CurriculumUnit.slugify(unit.title),
    );
    final row = await _client.from('curriculum_units').insert(columns).select().single();
    return CurriculumUnit.fromMap(row);
  }

  /// [changes] uses the same app-facing keys as [CurriculumUnit.toMap]
  /// (e.g. from the CMS unit form), translated to real column names here.
  Future<void> updateUnit(String id, Map<String, dynamic> changes) async {
    final columns = CurriculumUnit.mapToColumns(changes);
    await _client.from('curriculum_units').update(columns).eq('id', id);
  }

  Future<void> deleteUnit(String id) async {
    await _client.from('curriculum_units').delete().eq('id', id);
  }

  Future<Lesson> createLesson(Lesson lesson) async {
    final row = await _client.from('lessons').insert(lesson.toMap()).select().single();
    return Lesson.fromMap(row);
  }

  Future<void> updateLesson(String id, Map<String, dynamic> changes) async {
    await _client.from('lessons').update(changes).eq('id', id);
  }

  Future<void> deleteLesson(String id) async {
    await _client.from('lessons').delete().eq('id', id);
  }

  Future<LessonItem> createLessonItem(LessonItem item) async {
    final row = await _client.from('lesson_items').insert(item.toMap()).select().single();
    return LessonItem.fromMap(row);
  }

  Future<void> updateLessonItem(String id, Map<String, dynamic> changes) async {
    await _client.from('lesson_items').update(changes).eq('id', id);
  }

  Future<void> deleteLessonItem(String id) async {
    await _client.from('lesson_items').delete().eq('id', id);
  }
}
