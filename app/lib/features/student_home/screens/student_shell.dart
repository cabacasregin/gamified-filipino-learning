import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/points_badge.dart';

/// Bottom-nav shell for the student-facing gamified app: Home (unit
/// picker), Rewards (wallet + catalog). Learn/assessment screens are
/// pushed on top of this shell rather than being nav tabs themselves,
/// since they're a focused, full-screen flow.
class StudentShell extends ConsumerWidget {
  final Widget child;
  const StudentShell({super.key, required this.child});

  static const _tabs = ['/student/home', '/student/rewards'];

  int _indexForLocation(String location) {
    if (location.startsWith('/student/rewards')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matuto ng Filipino'),
        actions: [
          if (profile != null) Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: PointsBadge(studentId: profile.id)),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.card_giftcard_rounded), label: 'Rewards'),
        ],
      ),
    );
  }
}
