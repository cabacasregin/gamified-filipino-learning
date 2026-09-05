import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Aggregates raw `points_transactions` rows (`{points, created_at}`) into
/// one bucket per calendar day — including days with zero activity — over
/// the trailing [days] days, then plots the sum as a line chart.
class PointsTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;
  final int days;

  const PointsTrendChart({super.key, required this.transactions, this.days = 14});

  List<MapEntry<DateTime, int>> _dailyTotals() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final buckets = <DateTime, int>{
      for (var i = days - 1; i >= 0; i--) startOfToday.subtract(Duration(days: i)): 0,
    };
    for (final row in transactions) {
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (!buckets.containsKey(day)) continue;
      final points = (row['points'] as num?)?.toInt() ?? 0;
      buckets[day] = (buckets[day] ?? 0) + points;
    }
    final sortedDays = buckets.keys.toList()..sort();
    return [for (final day in sortedDays) MapEntry(day, buckets[day]!)];
  }

  @override
  Widget build(BuildContext context) {
    final totals = _dailyTotals();
    final total = totals.fold<int>(0, (sum, e) => sum + e.value);

    if (total == 0) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            'No points earned in the last $days days.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final maxY = totals.map((e) => e.value).fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    final spots = [
      for (var i = 0; i < totals.length; i++) FlSpot(i.toDouble(), totals[i].value.toDouble()),
    ];

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY <= 0 ? 5 : maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY <= 0 ? 5 : maxY * 1.2) / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: Colors.black12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (totals.length / 4).clamp(1, totals.length).toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.round();
                  if (index < 0 || index >= totals.length) return const SizedBox.shrink();
                  final day = totals[index].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${day.month}/${day.day}', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final day = totals[spot.x.toInt()].key;
                return LineTooltipItem(
                  '${day.month}/${day.day}: ${spot.y.toInt()} pts',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}
