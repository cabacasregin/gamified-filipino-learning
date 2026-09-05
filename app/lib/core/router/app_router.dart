import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assessment/screens/assessment_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/cms/screens/cms_home_screen.dart';
import '../../features/cms/screens/teacher_shell.dart';
import '../../features/dashboard/screens/parent_dashboard_screen.dart';
import '../../features/dashboard/screens/parent_shell.dart';
import '../../features/dashboard/screens/teacher_dashboard_screen.dart';
import '../../features/learning/screens/learn_screen.dart';
import '../../features/learning/screens/unit_mode_screen.dart';
import '../../features/rewards/screens/parent_rewards_screen.dart';
import '../../features/rewards/screens/rewards_screen.dart';
import '../../features/student_home/screens/student_home_screen.dart';
import '../../features/student_home/screens/student_shell.dart';
import '../models/app_role.dart';
import '../models/curriculum_models.dart';
import '../providers/core_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (_, _) => authNotifier.value++);
  ref.listen(currentProfileProvider, (_, _) => authNotifier.value++);
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authAsync = ref.read(authStateChangesProvider);
      final session = authAsync.valueOrNull?.session ?? ref.read(authRepositoryProvider).currentUser;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (session == null) {
        return loggingIn ? null : '/login';
      }

      final profileAsync = ref.read(currentProfileProvider);
      final profile = profileAsync.valueOrNull;
      if (profile == null) {
        // Still resolving the profile row (or auth session set but sign-up
        // hasn't finished writing it yet) — stay put, the listener above
        // will re-run redirect once it resolves.
        return null;
      }

      final isOnCorrectArea = switch (profile.role) {
        AppRole.student => state.matchedLocation.startsWith('/student'),
        AppRole.teacher => state.matchedLocation.startsWith('/teacher'),
        AppRole.parent => state.matchedLocation.startsWith('/parent'),
      };

      if (loggingIn || state.matchedLocation == '/' || !isOnCorrectArea) {
        return switch (profile.role) {
          AppRole.student => '/student/home',
          AppRole.teacher => '/teacher/cms',
          AppRole.parent => '/parent/dashboard',
        };
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      ShellRoute(
        builder: (context, state, child) => StudentShell(child: child),
        routes: [
          GoRoute(path: '/student/home', builder: (context, state) => const StudentHomeScreen()),
          GoRoute(
            path: '/student/unit/:unitId',
            builder: (context, state) => UnitModeScreen(
              unitId: state.pathParameters['unitId']!,
              unit: state.extra as CurriculumUnit?,
            ),
          ),
          GoRoute(
            path: '/student/unit/:unitId/learn',
            builder: (context, state) => LearnScreen(unitId: state.pathParameters['unitId']!),
          ),
          GoRoute(
            path: '/student/unit/:unitId/assessment',
            builder: (context, state) => AssessmentScreen(unitId: state.pathParameters['unitId']!),
          ),
          GoRoute(path: '/student/rewards', builder: (context, state) => const RewardsScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(path: '/teacher/cms', builder: (context, state) => const CmsHomeScreen()),
          GoRoute(path: '/teacher/dashboard', builder: (context, state) => const TeacherDashboardScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ParentShell(child: child),
        routes: [
          GoRoute(path: '/parent/dashboard', builder: (context, state) => const ParentDashboardScreen()),
          GoRoute(path: '/parent/rewards', builder: (context, state) => const ParentRewardsScreen()),
        ],
      ),
    ],
  );
});
