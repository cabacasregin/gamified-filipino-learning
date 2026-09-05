import 'package:flutter/material.dart';

/// Placeholder — full "learn" flow (flip through lesson items, play
/// pronunciation, mark complete for low-value points) is owned by the
/// learning feature workstream.
class LearnScreen extends StatelessWidget {
  final String unitId;
  const LearnScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matuto')),
      body: Center(child: Text('Learn flow for unit $unitId coming soon.')),
    );
  }
}
