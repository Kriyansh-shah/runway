/// Who is using the app. There are no accounts yet: Runway only asks for a
/// name, and everything stays on this device. Real sign-in (Apple, Google,
/// email codes) arrives with the Squad backend; see ROADMAP.md.
library;

class UserProfile {
  const UserProfile({required this.name, this.email = ''});
  final String name;

  /// Empty for name-only profiles. Older installs may still have one from
  /// the old stand-in login screen.
  final String email;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

/// Error message for a name, or null when it's fine.
String? validateName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'What should we call you?';
  if (trimmed.length > 30) return 'Keep it under 30 characters.';
  return null;
}
