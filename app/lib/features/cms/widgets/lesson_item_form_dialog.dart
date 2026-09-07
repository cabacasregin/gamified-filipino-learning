import 'package:flutter/material.dart';

import '../../../core/models/curriculum_models.dart';

/// Create/edit dialog for a [LessonItem]. Returns the map of field values
/// on save (matching [LessonItem.toMap]'s keys, minus `lesson_id` which the
/// caller already knows), or null if cancelled.
Future<Map<String, dynamic>?> showLessonItemFormDialog(
  BuildContext context, {
  LessonItem? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _LessonItemFormDialog(existing: existing),
  );
}

class _LessonItemFormDialog extends StatefulWidget {
  final LessonItem? existing;
  const _LessonItemFormDialog({this.existing});

  @override
  State<_LessonItemFormDialog> createState() => _LessonItemFormDialogState();
}

class _LessonItemFormDialogState extends State<_LessonItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _english = TextEditingController(text: widget.existing?.englishText ?? '');
  late final _filipino = TextEditingController(text: widget.existing?.filipinoText ?? '');
  late final _emoji = TextEditingController(text: widget.existing?.emoji ?? '');
  late final _variants = TextEditingController(
    text: (widget.existing?.acceptedVariants ?? const []).join(', '),
  );
  late final _ttsOverride = TextEditingController(text: widget.existing?.ttsTextOverride ?? '');
  late final _imageUrl = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late final _sortOrder = TextEditingController(text: (widget.existing?.sortOrder ?? 0).toString());

  @override
  void dispose() {
    _english.dispose();
    _filipino.dispose();
    _emoji.dispose();
    _variants.dispose();
    _ttsOverride.dispose();
    _imageUrl.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final variants = _variants.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    Navigator.of(context).pop({
      'english_text': _english.text.trim(),
      'filipino_text': _filipino.text.trim(),
      'emoji': _emoji.text.trim().isEmpty ? '❓' : _emoji.text.trim(),
      'accepted_variants': variants,
      'tts_text': _ttsOverride.text.trim().isEmpty ? null : _ttsOverride.text.trim(),
      'image_url': _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      'sort_order': int.tryParse(_sortOrder.text.trim()) ?? 0,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New lesson item' : 'Edit lesson item'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _english,
                decoration: const InputDecoration(labelText: 'English text'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _filipino,
                decoration: const InputDecoration(labelText: 'Filipino text'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emoji,
                decoration: const InputDecoration(labelText: 'Emoji'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _variants,
                decoration: const InputDecoration(
                  labelText: 'Accepted speech variants (comma-separated)',
                  helperText: 'e.g. isa, isang, isahan — what a speech recognizer might hear',
                  helperMaxLines: 2,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ttsOverride,
                decoration: const InputDecoration(
                  labelText: 'TTS text override (optional)',
                  helperText: 'Leave blank to speak the Filipino text as-is',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _imageUrl,
                decoration: const InputDecoration(labelText: 'Image URL (optional)'),
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
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
