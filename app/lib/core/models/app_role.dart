/// Matches the `role` enum on the `profiles` table in Supabase.
enum AppRole {
  student,
  teacher,
  parent;

  static AppRole fromString(String value) {
    return AppRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => AppRole.student,
    );
  }
}
