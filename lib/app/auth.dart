/// Authentication boundary. The UI only knows [AuthService], so the local
/// stand-in below can be replaced by Supabase / Firebase / Sign in with Apple
/// without touching the login screen.
library;

class UserProfile {
  const UserProfile({required this.name, required this.email});
  final String name;
  final String email;

  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthService {
  Future<UserProfile> signIn({required String email, required String password});

  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Returns an error message, or null when the input is valid.
String? validateCredentials({
  required String email,
  required String password,
  String? name,
}) {
  if (name != null && name.trim().isEmpty) return 'What should we call you?';
  if (!_email.hasMatch(email.trim())) return 'That email doesn\'t look right.';
  if (password.length < 6) return 'Password needs at least 6 characters.';
  return null;
}

/// On-device stand-in: validates input, simulates latency, and accepts any
/// well-formed credentials. There is no server and nothing is stored.
class LocalAuthService implements AuthService {
  const LocalAuthService({this.latency = const Duration(milliseconds: 900)});
  final Duration latency;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final error = validateCredentials(email: email, password: password);
    if (error != null) throw AuthException(error);
    await Future<void>.delayed(latency);
    return UserProfile(name: nameFromEmail(email), email: email.trim());
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final error = validateCredentials(
      email: email,
      password: password,
      name: name,
    );
    if (error != null) throw AuthException(error);
    await Future<void>.delayed(latency);
    return UserProfile(name: name.trim(), email: email.trim());
  }

  @override
  Future<void> signOut() async {}
}

/// `alex.kim99@uni.edu` → `Alex`
String nameFromEmail(String email) {
  final local = email.trim().split('@').first;
  final word = RegExp('[A-Za-z]+').firstMatch(local)?.group(0) ?? 'friend';
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}
