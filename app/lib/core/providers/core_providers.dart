import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_role.dart';
import '../models/app_user_profile.dart';
import '../services/ai_helper_service.dart';
import '../services/auth_repository.dart';
import '../services/content_repository.dart';
import '../services/points_repository.dart';
import '../services/progress_repository.dart';
import '../services/rewards_repository.dart';
import '../services/speech_recognition_service.dart';
import '../services/tts_service.dart';

// --- Services (singletons for the app's lifetime) ---

final authRepositoryProvider = Provider((ref) => AuthRepository());
final contentRepositoryProvider = Provider((ref) => ContentRepository());
final pointsRepositoryProvider = Provider((ref) => PointsRepository());
final rewardsRepositoryProvider = Provider((ref) => RewardsRepository());
final progressRepositoryProvider = Provider((ref) => ProgressRepository());
final aiHelperServiceProvider = Provider((ref) => AiHelperService());
final ttsServiceProvider = Provider((ref) => TtsService());
final speechRecognitionServiceProvider = Provider((ref) => SpeechRecognitionService());

// --- Auth state ---

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// The signed-in user's profile row (role, name), or null if signed out /
/// not yet loaded. Re-fetches whenever the auth state changes.
final currentProfileProvider = FutureProvider<AppUserProfile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState?.session == null) return null;
  return ref.watch(authRepositoryProvider).fetchCurrentProfile();
});

final currentRoleProvider = Provider<AppRole?>((ref) {
  return ref.watch(currentProfileProvider).valueOrNull?.role;
});

/// Live points balance for a given student id (used for the student's own
/// wallet display and for parent/teacher dashboards).
final pointsBalanceProvider = StreamProvider.family<int, String>((ref, studentId) {
  return ref.watch(pointsRepositoryProvider).watchBalance(studentId);
});
