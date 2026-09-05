import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../providers/cms_providers.dart';
import '../widgets/ai_helper_sheet.dart';
import '../widgets/lesson_form_dialog.dart';
import 'lesson_items_screen.dart';

/// Lessons within one [CurriculumUnit] — simple CRUD, drilling into
/// [LessonItemsScreen] per lesson.
class UnitLessonsScreen extends ConsumerWidget {
  final CurriculumUnit unit;
  const UnitLessonsScreen({super.key, required this.unit});

  Future<void> _createLesson(BuildContext context, WidgetRef ref) async {
    final values = await showLessonFormDialog(context);
    if (values == null) return;
    try {
      await ref.read(contentRepositoryProvider).createLesson(Lesson(
            id: '',
            unitId: unit.id,
            title: values['title'] as String,
            sortOrder: values['sort_order'] as int,
          ));
      ref.invalidate(cmsLessonsProvider(unit.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not create lesson', e);
    }
  }

  Future<void> _editLesson(BuildContext context, WidgetRef ref, Lesson lesson) async {
    final values = await showLessonFormDialog(context, existing: lesson);
    if (values == null) return;
    try {
      await updateLesson(lesson.id, values);
      ref.invalidate(cmsLessonsProvider(unit.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not update lesson', e);
    }
  }

  Future<void> _deleteLesson(BuildContext context, WidgetRef ref, Lesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: Text('This will delete "${lesson.title}" and all of its items.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(contentRepositoryProvider).deleteLesson(lesson.id);
      ref.invalidate(cmsLessonsProvider(unit.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not delete lesson', e);
    }
  }

  void _showError(BuildContext context, String title, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title: $error')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(cmsLessonsProvider(unit.id));
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        appBar: AppBar(title: Text('${unit.iconEmoji} ${unit.title}')),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(cmsLessonsProvider(unit.id)),
          child: AsyncView(
            value: lessonsAsync,
            emptyMessage: 'No lessons yet in this unit. Tap + to create one.',
            isEmpty: (lessons) => lessons.isEmpty,
            builder: (lessons) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: lessons.length,
              itemBuilder: (context, index) {
                final lesson = lessons[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(lesson.title),
                    subtitle: Text('Order ${lesson.sortOrder}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit lesson',
                          onPressed: () => _editLesson(context, ref, lesson),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete lesson',
                          onPressed: () => _deleteLesson(context, ref, lesson),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LessonItemsScreen(unit: unit, lesson: lesson)),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'ai-helper-fab-unit',
              onPressed: () => AiHelperSheet.show(context, unitContext: unit.title),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI helper'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'new-lesson-fab',
              onPressed: () => _createLesson(context, ref),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
