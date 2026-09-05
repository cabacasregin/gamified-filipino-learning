import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/points_badge.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/unit_mastery_list.dart';
import 'student_progress_screen.dart';

/// Teacher's class-wide progress dashboard: one card per student with a
/// points balance and a compact unit-mastery preview. Tapping a card opens
/// the full [StudentProgressScreen] with a daily-points trend chart.
class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsForTeacherProvider);
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(studentsForTeacherProvider),
          child: AsyncView(
            value: studentsAsync,
            emptyMessage: 'No students assigned to your class yet.',
            isEmpty: (students) => students.isEmpty,
            builder: (students) => ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final studentId = student['id'] as String;
                final studentName = (student['full_name'] as String?) ?? 'Student';
                final masteryAsync = ref.watch(unitMasteryProvider(studentId));
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            StudentProgressScreen(studentId: studentId, studentName: studentName),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(child: Text(studentName.isEmpty ? '?' : studentName[0])),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(studentName,
                                    style: Theme.of(context).textTheme.titleMedium),
                              ),
                              PointsBadge(studentId: studentId),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AsyncView(
                            value: masteryAsync,
                            emptyMessage: 'No attempts yet.',
                            isEmpty: (rows) => rows.isEmpty,
                            builder: (rows) => UnitMasteryList(rows: rows, maxRows: 3),
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Tap for full details',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
