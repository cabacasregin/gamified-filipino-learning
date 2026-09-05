import 'package:flutter/material.dart';

import '../../../core/models/curriculum_models.dart';

/// Create/edit dialog for a [CurriculumUnit]. Returns the map of field
/// values on save (matching [CurriculumUnit.toMap]'s keys), or null if
/// cancelled. The caller is responsible for calling the repository.
Future<Map<String, dynamic>?> showUnitFormDialog(
  BuildContext context, {
  CurriculumUnit? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _UnitFormDialog(existing: existing),
  );
}

class _UnitFormDialog extends StatefulWidget {
  final CurriculumUnit? existing;
  const _UnitFormDialog({this.existing});

  @override
  State<_UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends State<_UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _titleFilipino = TextEditingController(text: widget.existing?.titleFilipino ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _iconEmoji = TextEditingController(text: widget.existing?.iconEmoji ?? '📘');
  late final _sortOrder =
      TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());

  @override
  void dispose() {
    _title.dispose();
    _titleFilipino.dispose();
    _description.dispose();
    _iconEmoji.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'title': _title.text.trim(),
      'title_filipino': _titleFilipino.text.trim(),
      'description': _description.text.trim(),
      'icon_emoji': _iconEmoji.text.trim().isEmpty ? '📘' : _iconEmoji.text.trim(),
      'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New unit' : 'Edit unit'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title (English)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleFilipino,
                decoration: const InputDecoration(labelText: 'Title (Filipino)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _iconEmoji,
                      decoration: const InputDecoration(labelText: 'Icon emoji'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sortOrder,
                      decoration: const InputDecoration(labelText: 'Sort order'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
