import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../providers/dashboard_providers.dart';
import '../widgets/student_progress_view.dart';

/// Parent's "how is my kid doing" dashboard: points, unit mastery, and a
/// points trend chart per child. With more than one child, a tab bar lets
/// the parent switch between them; with exactly one, the tab bar is
/// skipped and the view goes straight to the content.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(childrenForParentProvider);
    return Theme(
      data: AppTheme.adminTheme,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(childrenForParentProvider),
          child: AsyncView(
            value: childrenAsync,
            emptyMessage: 'No children linked to your account yet.',
            isEmpty: (children) => children.isEmpty,
            builder: (children) {
              if (children.length == 1) {
                final child = children.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        (child['full_name'] as String?) ?? 'Your child',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Expanded(
                      child: StudentProgressView(studentId: child['id'] as String),
                    ),
                  ],
                );
              }
              return DefaultTabController(
                length: children.length,
                child: Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        isScrollable: true,
                        tabs: [
                          for (final child in children)
                            Tab(text: (child['full_name'] as String?) ?? 'Child'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final child in children)
                            StudentProgressView(studentId: child['id'] as String),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
