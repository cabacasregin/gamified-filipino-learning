import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/curriculum_models.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unit != null) Text(unit!.iconEmoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.menu_book),
                label: const Text('Matuto (Learn)'),
                onPressed: () => context.go('/student/unit/$unitId/learn', extra: unit),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('Subukan (Assessment)'),
                onPressed: () => context.go('/student/unit/$unitId/assessment', extra: unit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
