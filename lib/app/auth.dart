/// Who is using the app. Runway asks only for a name; signing in with
/// Google is optional and links an account for Squad. Money data stays on
/// this device either way; see ROADMAP.md.
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

/// A Google account linked through Supabase. Only the email and first name
/// come from Google; money data never goes to the server.
class Account {
  const Account({required this.id, required this.email, this.firstName = ''});
  final String id;
  final String email;
  final String firstName;
}

/// Why signing in, out or deleting didn't work, in words for the person.
class AccountException implements Exception {
  const AccountException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Optional sign-in, behind an interface so tests and platforms without
/// Google sign-in (macOS preview, web) use [NoAccounts].
abstract interface class AccountService {
  /// Whether "Continue with Google" can be offered on this device.
  bool get canUseGoogle;

  /// The signed-in account, or null.
  Account? get current;

  /// Shows Google's account picker. Null when the person backs out;
  /// throws [AccountException] when it fails.
  Future<Account?> signInWithGoogle();

  /// Signs out on this phone. Nothing on the phone is erased.
  Future<void> signOut();

  /// Deletes the account and everything stored with it on the server, then
  /// signs out.
  Future<void> deleteAccount();
}

/// No sign-in at all: name-only, like before accounts existed.
class NoAccounts implements AccountService {
  const NoAccounts();

  @override
  bool get canUseGoogle => false;

  @override
  Account? get current => null;

  @override
  Future<Account?> signInWithGoogle() async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

/// The first name to greet someone by, from a full name like "Alex Kim",
/// within [validateName]'s limits.
String firstNameOf(String fullName) {
  final first = fullName.trim().split(RegExp(r'\s+')).first;
  return first.length > 30 ? first.substring(0, 30) : first;
}
