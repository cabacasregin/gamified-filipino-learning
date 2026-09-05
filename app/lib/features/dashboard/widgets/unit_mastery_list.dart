import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Renders per-unit accuracy as a compact list of labeled progress bars.
/// Rows come from `student_unit_mastery`:
/// `{unit_id, unit_title, total_items, attempted_count, correct_count, accuracy}`.
///
/// `accuracy` is treated defensively: if it looks like a fraction (<=1) it's
/// read as one, otherwise as an already-computed percentage — the RPC's
/// exact scale isn't nailed down by the spec, so this covers both.
class UnitMasteryList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final int? maxRows;

  const UnitMasteryList({super.key, required this.rows, this.maxRows});

  static double _asFraction(dynamic accuracy) {
    final value = (accuracy as num?)?.toDouble() ?? 0.0;
    return value <= 1.0 ? value : value / 100.0;
  }

  Color _colorFor(double fraction, BuildContext context) {
    if (fraction >= 0.8) return AppColors.success;
    if (fraction >= 0.5) return AppColors.secondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No attempts recorded yet.'),
      );
    }
    final visible = maxRows == null ? rows : rows.take(maxRows!).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in visible) ...[
          _UnitMasteryRow(row: row, fraction: _asFraction(row['accuracy']), color: _colorFor(_asFraction(row['accuracy']), context)),
          const SizedBox(height: 10),
        ],
        if (maxRows != null && rows.length > maxRows!)
          Text(
            '+${rows.length - maxRows!} more unit${rows.length - maxRows! == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
      ],
    );
  }
}

class _UnitMasteryRow extends StatelessWidget {
  final Map<String, dynamic> row;
  final double fraction;
  final Color color;

  const _UnitMasteryRow({required this.row, required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final title = (row['unit_title'] as String?) ?? 'Unit';
    final attempted = (row['attempted_count'] as num?)?.toInt() ?? 0;
    final total = (row['total_items'] as num?)?.toInt() ?? 0;
    final correct = (row['correct_count'] as num?)?.toInt() ?? 0;
    final percentLabel = '${(fraction * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(percentLabel, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$correct correct of $attempted attempted · $total item${total == 1 ? '' : 's'} total',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
