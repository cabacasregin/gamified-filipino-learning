import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/points_badge.dart';
import '../providers/dashboard_providers.dart';
import 'points_trend_chart.dart';
import 'unit_mastery_list.dart';

/// Full progress breakdown for one student: live points balance, per-unit
/// mastery, and a points-over-time trend chart. Shared between the
/// teacher's per-student detail push and the parent dashboard's per-child
/// view (embedded directly, no navigation needed there).
class StudentProgressView extends ConsumerWidget {
  final String studentId;

  const StudentProgressView({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masteryAsync = ref.watch(unitMasteryProvider(studentId));
    final dailyPointsAsync = ref.watch(dailyPointsProvider(studentId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(unitMasteryProvider(studentId));
        ref.invalidate(dailyPointsProvider(studentId));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('Points balance', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              PointsBadge(studentId: studentId),
            ],
          ),
          const SizedBox(height: 20),
          Text('Points over the last 14 days', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: AsyncView(
                value: dailyPointsAsync,
                builder: (rows) => PointsTrendChart(transactions: rows),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Unit mastery', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AsyncView(
                value: masteryAsync,
                emptyMessage: 'No unit attempts recorded yet.',
                isEmpty: (rows) => rows.isEmpty,
                builder: (rows) => UnitMasteryList(rows: rows),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
