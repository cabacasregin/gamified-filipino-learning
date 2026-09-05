import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../theme/app_theme.dart';

/// Small pill showing a student's live points balance. Used in the
/// student app bar and on teacher/parent progress cards.
class PointsBadge extends ConsumerWidget {
  final String studentId;

  const PointsBadge({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(pointsBalanceProvider(studentId));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.points.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            balance.when(
              data: (v) => '$v pts',
              loading: () => '…',
              error: (_, _) => '—',
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
