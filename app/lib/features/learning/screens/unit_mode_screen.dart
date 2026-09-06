import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/theme/app_theme.dart';

/// Lets the student choose between the low-stakes "Learn" flow and the
/// higher-value "Assessment" (speak-the-answer) flow for a unit.
class UnitModeScreen extends StatelessWidget {
  final String unitId;
  final CurriculumUnit? unit;

  const UnitModeScreen({super.key, required this.unitId, this.unit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(unit?.titleFilipino ?? 'Lesson')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unit != null) ...[
                Text(unit!.iconEmoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  unit!.titleFilipino,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  unit!.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Piliin ang gagawin (Choose what to do)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.menu_book_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Matuto (Learn)'),
                  onPressed: () => context.go('/student/unit/$unitId/learn', extra: unit),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.mic_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Subukan (Assessment)'),
                  onPressed: () => context.go('/student/unit/$unitId/assessment', extra: unit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
