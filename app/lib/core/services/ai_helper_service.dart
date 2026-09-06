import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum AiHelperMode { suggestLessonItems, generatePracticePrompt, translateCheck, freeChat }

extension on AiHelperMode {
  String get wireValue => switch (this) {
    AiHelperMode.suggestLessonItems => 'suggest_lesson_items',
    AiHelperMode.generatePracticePrompt => 'generate_practice_prompt',
    AiHelperMode.translateCheck => 'translate_check',
    AiHelperMode.freeChat => 'free_chat',
  };
}

/// Calls the `ai-helper` Supabase Edge Function, which proxies Gemini
/// server-side so the API key never ships to the browser/app. Used by the
/// teacher CMS to draft new vocabulary, sanity-check translations, and
/// generate practice prompts.
class AiHelperService {
  final SupabaseClient _client = SupabaseService.client;

  Future<String> ask({
    required AiHelperMode mode,
    required String prompt,
    String? unitContext,
  }) async {
    final response = await _client.functions.invoke(
      'ai-helper',
      body: {
        'mode': mode.wireValue,
        'prompt': prompt,
        if (unitContext != null) 'unit_context': unitContext,
      },
    );
    if (response.status != 200) {
      throw Exception('AI helper request failed (${response.status}): ${response.data}');
    }
    final data = response.data;
    if (data is Map && data['text'] is String) {
      return data['text'] as String;
    }
    return data.toString();
  }
}
