import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';

/// Nav shell for teachers: content CMS + class progress dashboard.
class TeacherShell extends ConsumerWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  static const _tabs = ['/teacher/cms', '/teacher/dashboard'];

  int _indexFor(String location) => location.startsWith('/teacher/dashboard') ? 1 : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher CMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexFor(location),
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_note), label: 'Content'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}
