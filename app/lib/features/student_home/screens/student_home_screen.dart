import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/async_view.dart';

final curriculumUnitsProvider = FutureProvider<List<CurriculumUnit>>((ref) {
  return ref.watch(contentRepositoryProvider).fetchUnits();
});

/// Landing screen for students: a grid of curriculum units (Alpabetong
/// Filipino, Mga Numero, Mga Hugis, Mga Kulay, ...). Tapping a unit goes to
/// the learning-vs-assessment mode picker owned by the `learning` feature.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(curriculumUnitsProvider);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(curriculumUnitsProvider.future),
      child: AsyncView<List<CurriculumUnit>>(
        value: unitsAsync,
        emptyMessage: 'Wala pang lessons. Balik ka mamaya!',
        isEmpty: (data) => data.isEmpty,
        builder: (units) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.05,
          ),
          itemCount: units.length,
          itemBuilder: (context, i) {
            final unit = units[i];
            return _UnitCard(unit: unit);
          },
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final CurriculumUnit unit;
  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/student/unit/${unit.id}', extra: unit),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(unit.iconEmoji, style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                unit.titleFilipino.isNotEmpty ? unit.titleFilipino : unit.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                unit.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
