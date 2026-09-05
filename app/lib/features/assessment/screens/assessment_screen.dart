import 'package:flutter/material.dart';

/// Placeholder — full spoken-assessment flow (speech_to_text capture,
/// AnswerMatcher scoring, correction UI, multiplier points) is owned by
/// the assessment feature workstream.
class AssessmentScreen extends StatelessWidget {
  final String unitId;
  const AssessmentScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subukan')),
      body: Center(child: Text('Assessment flow for unit $unitId coming soon.')),
    );
  }
}
