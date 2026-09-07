import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/core_providers.dart';

/// Nav shell for parents: children's progress dashboard + reward
/// management.
class ParentShell extends ConsumerWidget {
  final Widget child;
  const ParentShell({super.key, required this.child});

  static const _tabs = ['/parent/dashboard', '/parent/rewards'];

  int _indexFor(String location) => location.startsWith('/parent/rewards') ? 1 : 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
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
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
          NavigationDestination(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
        ],
      ),
    );
  }
}
