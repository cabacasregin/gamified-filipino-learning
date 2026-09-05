import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FilipinoLearnApp extends ConsumerWidget {
  const FilipinoLearnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Matuto ng Filipino',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.studentTheme,
      routerConfig: router,
    );
  }
}
