import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';

/// Every [LessonItem] across a unit's lessons, flattened in curriculum
/// order — the flashcard deck for the low-stakes "Learn" flow. Keyed by
/// unit id so switching units (or re-entering the same one) re-fetches.
final unitLearnItemsProvider = FutureProvider.family<List<LessonItem>, String>((ref, unitId) {
  return ref.watch(contentRepositoryProvider).fetchUnitItems(unitId);
});
