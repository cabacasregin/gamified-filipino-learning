import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../providers/cms_providers.dart';
import '../widgets/ai_helper_sheet.dart';
import '../widgets/lesson_item_form_dialog.dart';

/// Lesson items (English-Filipino pairs) within one [Lesson]. This is
/// where the AI helper is most useful, so it's opened here with the
/// lesson id in context so suggestions can be added with one tap.
class LessonItemsScreen extends ConsumerWidget {
  final CurriculumUnit unit;
  final Lesson lesson;
  const LessonItemsScreen({super.key, required this.unit, required this.lesson});

  Future<void> _createItem(BuildContext context, WidgetRef ref) async {
    final values = await showLessonItemFormDialog(context);
    if (values == null) return;
    try {
      await ref
          .read(contentRepositoryProvider)
          .createLessonItem(
            LessonItem(
              id: '',
              lessonId: lesson.id,
              englishText: values['english_text'] as String,
              filipinoText: values['filipino_text'] as String,
              emoji: values['emoji'] as String,
              imageUrl: values['image_url'] as String?,
              ttsTextOverride: values['tts_text'] as String?,
              acceptedVariants: List<String>.from(values['accepted_variants'] as List),
              sortOrder: values['sort_order'] as int,
            ),
          );
      ref.invalidate(cmsLessonItemsProvider(lesson.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not create item', e);
    }
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref, LessonItem item) async {
    final values = await showLessonItemFormDialog(context, existing: item);
    if (values == null) return;
    try {
      await ref.read(contentRepositoryProvider).updateLessonItem(item.id, values);
      ref.invalidate(cmsLessonItemsProvider(lesson.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not update item', e);
    }
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, LessonItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('This will delete "${item.englishText} / ${item.filipinoText}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
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
      await ref.read(contentRepositoryProvider).deleteLessonItem(item.id);
      ref.invalidate(cmsLessonItemsProvider(lesson.id));
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not delete item', e);
    }
  }

  void _showError(BuildContext context, String title, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title: $error')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(cmsLessonItemsProvider(lesson.id));
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        appBar: AppBar(title: Text(lesson.title)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(cmsLessonItemsProvider(lesson.id)),
          child: AsyncView(
            value: itemsAsync,
            emptyMessage: 'No items yet in this lesson. Tap + to add one, or ask the AI helper.',
            isEmpty: (items) => items.isEmpty,
            builder: (items) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: ListTile(
                    leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text('${item.englishText} → ${item.filipinoText}'),
                    subtitle: Text(
                      item.acceptedVariants.isEmpty
                          ? 'No accepted variants set'
                          : 'Variants: ${item.acceptedVariants.join(', ')}',
                    ),
                    isThreeLine: item.acceptedVariants.isNotEmpty,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit item',
                          onPressed: () => _editItem(context, ref, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete item',
                          onPressed: () => _deleteItem(context, ref, item),
                        ),
                      ],
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
              heroTag: 'ai-helper-fab-lesson',
              onPressed: () => AiHelperSheet.show(
                context,
                unitContext: '${unit.title} — ${lesson.title}',
                lessonId: lesson.id,
                onItemAdded: () => ref.invalidate(cmsLessonItemsProvider(lesson.id)),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI helper'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'new-item-fab',
              onPressed: () => _createItem(context, ref),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
