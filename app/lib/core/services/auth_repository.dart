import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_role.dart';
import '../models/app_user_profile.dart';
import 'supabase_service.dart';

/// Handles Supabase auth + the associated `profiles` row (role, name).
class AuthRepository {
  final SupabaseClient _client = SupabaseService.client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Creates the auth user and its `profiles` row in one go. `parentId` is
  /// set when a parent is creating a linked student account.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required AppRole role,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final userId = response.user?.id;
    if (userId == null) {
      throw AuthException('Sign up did not return a user id.');
    }
    await _client.from('profiles').upsert({'id': userId, 'role': role.name, 'full_name': fullName});
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<AppUserProfile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    return AppUserProfile.fromMap(row);
  }

  /// Links an existing student account to the signed-in parent, by the
  /// student's profile id. Requires the caller to already be authenticated
  /// as a parent (enforced by RLS on `parent_children`).
  Future<void> linkChild({required String studentProfileId}) async {
    final parentId = currentUser?.id;
    if (parentId == null) throw AuthException('Not signed in.');
    await _client.from('parent_children').upsert({
      'parent_id': parentId,
      'student_id': studentProfileId,
    });
  }
}
