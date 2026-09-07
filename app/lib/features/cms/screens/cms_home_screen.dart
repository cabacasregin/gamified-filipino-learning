import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../providers/cms_providers.dart';
import '../widgets/ai_helper_sheet.dart';
import '../widgets/unit_form_dialog.dart';
import 'unit_lessons_screen.dart';

/// Root CMS screen: curriculum units list with create/edit/delete, plus the
/// entry point to the AI helper. Drilling into a unit pushes
/// [UnitLessonsScreen].
class CmsHomeScreen extends ConsumerWidget {
  const CmsHomeScreen({super.key});

  Future<void> _createUnit(BuildContext context, WidgetRef ref) async {
    final values = await showUnitFormDialog(context);
    if (values == null) return;
    try {
      await ref
          .read(contentRepositoryProvider)
          .createUnit(
            CurriculumUnit(
              id: '',
              title: values['title'] as String,
              titleFilipino: values['title_filipino'] as String,
              description: values['description'] as String,
              iconEmoji: values['icon_emoji'] as String,
              sortOrder: values['sort_order'] as int,
            ),
          );
      ref.invalidate(cmsUnitsProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not create unit', e);
    }
  }

  Future<void> _editUnit(BuildContext context, WidgetRef ref, CurriculumUnit unit) async {
    final values = await showUnitFormDialog(context, existing: unit);
    if (values == null) return;
    try {
      await ref.read(contentRepositoryProvider).updateUnit(unit.id, values);
      ref.invalidate(cmsUnitsProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not update unit', e);
    }
  }

  Future<void> _deleteUnit(BuildContext context, WidgetRef ref, CurriculumUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete unit?'),
        content: Text(
          'This will delete "${unit.title}" and all of its lessons and items. This cannot be undone.',
        ),
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
      await ref.read(contentRepositoryProvider).deleteUnit(unit.id);
      ref.invalidate(cmsUnitsProvider);
    } catch (e) {
      if (context.mounted) _showError(context, 'Could not delete unit', e);
    }
  }

  void _showError(BuildContext context, String title, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title: $error')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(cmsUnitsProvider);
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(cmsUnitsProvider),
          child: AsyncView(
            value: unitsAsync,
            emptyMessage: 'No curriculum units yet. Tap + to create one.',
            isEmpty: (units) => units.isEmpty,
            builder: (units) => ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: units.length,
              itemBuilder: (context, index) {
                final unit = units[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(unit.iconEmoji, style: const TextStyle(fontSize: 18)),
                    ),
                    title: Text(unit.title),
                    subtitle: Text(
                      '${unit.titleFilipino.isEmpty ? '—' : unit.titleFilipino} · order ${unit.sortOrder}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit unit',
                          onPressed: () => _editUnit(context, ref, unit),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete unit',
                          onPressed: () => _deleteUnit(context, ref, unit),
                        ),
                      ],
                    ),
                    onTap: () =>
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => UnitLessonsScreen(unit: unit))),
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
              heroTag: 'ai-helper-fab',
              onPressed: () => AiHelperSheet.show(context),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('AI helper'),
            ),
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'new-unit-fab',
              onPressed: () => _createUnit(context, ref),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
