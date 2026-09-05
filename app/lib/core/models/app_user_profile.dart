import 'package:equatable/equatable.dart';

import 'app_role.dart';

/// Mirrors a row in the `profiles` table.
class AppUserProfile extends Equatable {
  final String id;
  final AppRole role;
  final String fullName;
  final String? avatarUrl;

  const AppUserProfile({
    required this.id,
    required this.role,
    required this.fullName,
    this.avatarUrl,
  });

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      id: map['id'] as String,
      role: AppRole.fromString(map['role'] as String),
      fullName: (map['full_name'] as String?) ?? '',
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, role, fullName, avatarUrl];
}
