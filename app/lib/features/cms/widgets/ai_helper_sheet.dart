import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/ai_helper_service.dart';

/// Modal sheet housing the teacher-facing AI helper: lesson-item
/// suggestions, a translation sanity-checker, and a free-form question box.
///
/// All three modes share one Gemini-backed edge function
/// ([AiHelperService]); this widget is purely presentational plumbing on
/// top of it, plus best-effort JSON parsing for the suggestion mode so
/// teachers can add suggested items with one tap instead of retyping them.
class AiHelperSheet extends StatelessWidget {
  final String? initialUnitContext;
  final String? lessonId;
  final VoidCallback? onItemAdded;

  const AiHelperSheet({
    super.key,
    this.initialUnitContext,
    this.lessonId,
    this.onItemAdded,
  });

  /// Opens the helper as a tall draggable bottom sheet.
  ///
  /// Pass [lessonId] when opening from within a specific lesson so
  /// suggested items can be added directly; omit it (e.g. from the units
  /// list) to fall back to read-only suggestions.
  static Future<void> show(
    BuildContext context, {
    String? unitContext,
    String? lessonId,
    VoidCallback? onItemAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        expand: false,
        builder: (context, scrollController) => AiHelperSheet(
          initialUnitContext: unitContext,
          lessonId: lessonId,
          onItemAdded: onItemAdded,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Text('AI Curriculum Helper', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Suggest items'),
              Tab(text: 'Check translation'),
              Tab(text: 'Ask anything'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SuggestItemsTab(
                  initialUnitContext: initialUnitContext,
                  lessonId: lessonId,
                  onItemAdded: onItemAdded,
                ),
                const _TranslateCheckTab(),
                const _FreeChatTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared "ask Gemini, show a friendly error, render the raw text" shell
/// used by all three tabs so error/loading handling stays consistent.
class _AiQueryScaffold extends ConsumerStatefulWidget {
  final String submitLabel;
  final List<Widget> Function(
    BuildContext context,
    TextEditingController controller,
  ) buildInputs;
  final Future<String> Function(AiHelperService service) onSubmit;
  final Widget Function(BuildContext context, String rawResponse)? buildExtra;

  const _AiQueryScaffold({
    required this.submitLabel,
    required this.buildInputs,
    required this.onSubmit,
    this.buildExtra,
  });

  @override
  ConsumerState<_AiQueryScaffold> createState() => _AiQueryScaffoldState();
}

class _AiQueryScaffoldState extends ConsumerState<_AiQueryScaffold> {
  bool _loading = false;
  String? _error;
  String? _response;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final service = ref.read(aiHelperServiceProvider);
      final text = await widget.onSubmit(service);
      if (!mounted) return;
      setState(() => _response = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          "Couldn't reach the AI helper. It may be offline or misconfigured — please try again in a moment.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InputsHost(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(widget.submitLabel),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_response != null) ...[
            const SizedBox(height: 16),
            if (widget.buildExtra != null) widget.buildExtra!(context, _response!),
            const SizedBox(height: 8),
            Text('Raw response', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_response!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Placeholder swapped out by [_AiQueryScaffold]'s caller — kept as a
/// separate widget only so `buildInputs` gets a fresh [BuildContext] scope.
/// (Intentionally unused directly; each tab supplies its own inputs via the
/// `_SuggestItemsTab` / `_TranslateCheckTab` / `_FreeChatTab` bodies below,
/// which embed the scaffold with their own controllers.)
class _InputsHost extends StatelessWidget {
  const _InputsHost();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// --- Suggest lesson items -------------------------------------------------

class _SuggestItemsTab extends ConsumerStatefulWidget {
  final String? initialUnitContext;
  final String? lessonId;
  final VoidCallback? onItemAdded;

  const _SuggestItemsTab({this.initialUnitContext, this.lessonId, this.onItemAdded});

  @override
  ConsumerState<_SuggestItemsTab> createState() => _SuggestItemsTabState();
}

class _SuggestItemsTabState extends ConsumerState<_SuggestItemsTab> {
  late final _unitContextController =
      TextEditingController(text: widget.initialUnitContext ?? '');
  final _promptController = TextEditingController(
    text: 'Suggest 5 new vocabulary items with English text, Filipino text, an emoji, '
        'and 2-4 accepted speech-recognition variants each.',
  );

  bool _loading = false;
  String? _error;
  String? _rawResponse;
  List<Map<String, dynamic>>? _parsedItems;
  final Set<int> _added = {};

  @override
  void dispose() {
    _unitContextController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
      _rawResponse = null;
      _parsedItems = null;
      _added.clear();
    });
    try {
      final service = ref.read(aiHelperServiceProvider);
      final text = await service.ask(
        mode: AiHelperMode.suggestLessonItems,
        prompt:
            '${_promptController.text}\n\nRespond with a JSON array of objects, each with keys '
            '"english_text", "filipino_text", "emoji", and "accepted_variants" (a list of strings). '
            'You may add a short explanation before or after the JSON.',
        unitContext:
            _unitContextController.text.trim().isEmpty ? null : _unitContextController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _rawResponse = text;
        _parsedItems = _tryParseSuggestions(text);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          "Couldn't reach the AI helper. It may be offline or misconfigured — please try again in a moment.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addItem(int index, Map<String, dynamic> item) async {
    final lessonId = widget.lessonId;
    if (lessonId == null) return;
    try {
      final repo = ref.read(contentRepositoryProvider);
      await repo.createLessonItem(LessonItem(
        id: '',
        lessonId: lessonId,
        englishText: (item['english_text'] ?? item['englishText'] ?? '').toString(),
        filipinoText: (item['filipino_text'] ?? item['filipinoText'] ?? '').toString(),
        emoji: (item['emoji'] ?? '❓').toString(),
        acceptedVariants: _asStringList(item['accepted_variants'] ?? item['variants']),
        sortOrder: index,
      ));
      if (!mounted) return;
      setState(() => _added.add(index));
      widget.onItemAdded?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to this lesson.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add item: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _unitContextController,
            decoration: const InputDecoration(
              labelText: 'Topic / unit context',
              hintText: 'e.g. Mga Numero 11-20',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'What do you need?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: const Text('Suggest items'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(_error!),
          ],
          if (_parsedItems != null && _parsedItems!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Suggestions', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            if (widget.lessonId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Open this helper from inside a lesson to add suggestions directly.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            for (var i = 0; i < _parsedItems!.length; i++)
              Card(
                child: ListTile(
                  leading: Text(
                    (_parsedItems![i]['emoji'] ?? '❓').toString(),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    '${_parsedItems![i]['english_text'] ?? _parsedItems![i]['englishText'] ?? '?'} '
                    '→ ${_parsedItems![i]['filipino_text'] ?? _parsedItems![i]['filipinoText'] ?? '?'}',
                  ),
                  subtitle: Text(
                    'Variants: ${_asStringList(_parsedItems![i]['accepted_variants'] ?? _parsedItems![i]['variants']).join(', ')}',
                  ),
                  trailing: widget.lessonId == null
                      ? null
                      : _added.contains(i)
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              tooltip: 'Add to this lesson',
                              onPressed: () => _addItem(i, _parsedItems![i]),
                            ),
                ),
              ),
          ],
          if (_rawResponse != null) ...[
            const SizedBox(height: 16),
            Text('Raw response', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_rawResponse!),
            ),
          ],
        ],
      ),
    );
  }
}

List<String> _asStringList(dynamic value) {
  if (value is List) return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  if (value is String && value.isNotEmpty) {
    return value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  return const [];
}

/// Best-effort extraction of a JSON array of suggestion objects from a
/// free-form Gemini response. Tries a ```json fenced block first, then
/// falls back to the outermost `[...]` in the text. Returns null (never
/// throws) if nothing parseable is found — callers must always keep
/// showing the raw text as a fallback.
List<Map<String, dynamic>>? _tryParseSuggestions(String raw) {
  final candidates = <String>[];
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(raw);
  if (fence != null) candidates.add(fence.group(1)!.trim());
  final start = raw.indexOf('[');
  final end = raw.lastIndexOf(']');
  if (start != -1 && end > start) candidates.add(raw.substring(start, end + 1));

  for (final candidate in candidates) {
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is List) {
        final items = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (items.isNotEmpty) return items;
      }
    } catch (_) {
      // Try the next candidate.
    }
  }
  return null;
}

// --- Translation sanity check --------------------------------------------

class _TranslateCheckTab extends ConsumerStatefulWidget {
  const _TranslateCheckTab();

  @override
  ConsumerState<_TranslateCheckTab> createState() => _TranslateCheckTabState();
}

class _TranslateCheckTabState extends ConsumerState<_TranslateCheckTab> {
  final _englishController = TextEditingController();
  final _filipinoController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _response;

  @override
  void dispose() {
    _englishController.dispose();
    _filipinoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_englishController.text.trim().isEmpty || _filipinoController.text.trim().isEmpty) {
      setState(() => _error = 'Enter both an English and a Filipino phrase.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final service = ref.read(aiHelperServiceProvider);
      final text = await service.ask(
        mode: AiHelperMode.translateCheck,
        prompt: 'English: ${_englishController.text.trim()}\n'
            'Filipino: ${_filipinoController.text.trim()}\n\n'
            'Is this translation accurate and age-appropriate for the MATATAG Filipino '
            'curriculum (Kindergarten-Grade 3)? If not, explain why and suggest a correction.',
      );
      if (!mounted) return;
      setState(() => _response = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          "Couldn't reach the AI helper. It may be offline or misconfigured — please try again in a moment.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _englishController,
            decoration: const InputDecoration(labelText: 'English', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _filipinoController,
            decoration: const InputDecoration(labelText: 'Filipino', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fact_check),
            label: const Text('Check translation'),
          ),
          if (_error != null) ...[const SizedBox(height: 16), _ErrorBanner(_error!)],
          if (_response != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_response!),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Free chat -------------------------------------------------------------

class _FreeChatTab extends ConsumerStatefulWidget {
  const _FreeChatTab();

  @override
  ConsumerState<_FreeChatTab> createState() => _FreeChatTabState();
}

class _FreeChatTabState extends ConsumerState<_FreeChatTab> {
  final _promptController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _response;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_promptController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _response = null;
    });
    try {
      final service = ref.read(aiHelperServiceProvider);
      final text = await service.ask(
        mode: AiHelperMode.freeChat,
        prompt: _promptController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _response = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error =
          "Couldn't reach the AI helper. It may be offline or misconfigured — please try again in a moment.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Ask anything',
              hintText: 'e.g. Give me 5 practice sentences using colors.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Ask'),
          ),
          if (_error != null) ...[const SizedBox(height: 16), _ErrorBanner(_error!)],
          if (_response != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(_response!),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
