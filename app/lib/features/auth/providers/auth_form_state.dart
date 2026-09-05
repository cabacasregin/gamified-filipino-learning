import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_role.dart';
import '../../../core/providers/core_providers.dart';

enum AuthStatus { idle, submitting, error }

class AuthFormNotifier extends StateNotifier<({AuthStatus status, String? errorMessage})> {
  final Ref ref;
  AuthFormNotifier(this.ref) : super((status: AuthStatus.idle, errorMessage: null));

  Future<bool> signIn(String email, String password) async {
    state = (status: AuthStatus.submitting, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).signIn(email: email, password: password);
      state = (status: AuthStatus.idle, errorMessage: null);
      return true;
    } catch (e) {
      state = (status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required AppRole role,
  }) async {
    state = (status: AuthStatus.submitting, errorMessage: null);
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
            fullName: fullName,
            role: role,
          );
      state = (status: AuthStatus.idle, errorMessage: null);
      return true;
    } catch (e) {
      state = (status: AuthStatus.error, errorMessage: e.toString());
      return false;
    }
  }
}

final authFormProvider =
    StateNotifierProvider<AuthFormNotifier, ({AuthStatus status, String? errorMessage})>(
  (ref) => AuthFormNotifier(ref),
);
