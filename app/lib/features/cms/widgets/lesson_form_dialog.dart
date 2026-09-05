import 'package:flutter/material.dart';

import '../../../core/models/curriculum_models.dart';

/// Create/edit dialog for a [Lesson]. Returns the map of field values on
/// save (matching [Lesson.toMap]'s keys, minus `unit_id` which the caller
/// already knows), or null if cancelled.
Future<Map<String, dynamic>?> showLessonFormDialog(
  BuildContext context, {
  Lesson? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _LessonFormDialog(existing: existing),
  );
}

class _LessonFormDialog extends StatefulWidget {
  final Lesson? existing;
  const _LessonFormDialog({this.existing});

  @override
  State<_LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<_LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _sortOrder =
      TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());

  @override
  void dispose() {
    _title.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'title': _title.text.trim(),
      'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New lesson' : 'Edit lesson'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sortOrder,
              decoration: const InputDecoration(labelText: 'Sort order'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
