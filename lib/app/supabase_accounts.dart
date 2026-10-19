/// Google sign-in through Supabase Auth. Google shows its own account
/// picker and returns a signed ID token; Supabase checks it and starts a
/// session, kept in the Keychain / Keystore.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth.dart';

/// The Supabase project. The URL and publishable key ship inside the app
/// and are safe to share; row-level security decides what anyone can read.
const supabaseUrl = 'https://slvwntpzgjpqzmojzdus.supabase.co';
const supabasePublishableKey = 'sb_publishable_0tPZA1of46JijBkugDNQsA_FBJnMkW1';

/// Google OAuth clients. Android finds its own client by package name and
/// signing SHA-1, so only the web (server) and iOS IDs appear in code.
const _googleWebClientId =
    '363749449062-b58d78p22u63kkh0btc85f7ptj8dq1lg.apps.googleusercontent.com';
const _googleIosClientId =
    '363749449062-lkvjpjh5qk55co4fv5dvq5s7f7qqq9hh.apps.googleusercontent.com';

class SupabaseAccounts implements AccountService {
  SupabaseAccounts._(this._nonce);

  /// Raw nonce for this run. Google puts its SHA-256 in the ID token and
  /// Supabase checks it, so a stolen token can't be replayed.
  final String _nonce;

  SupabaseClient get _client => Supabase.instance.client;

  /// Only iPhone and Android have Google sign-in set up.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  /// Connects to Supabase and restores a saved session. Call once at launch
  /// on a [supported] platform. Works offline; the session refreshes later.
  static Future<SupabaseAccounts> start() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        localStorage: _SecureSessionStorage(),
        // No email or OAuth links come back into the app yet.
        detectSessionInUri: false,
      ),
    );
    final random = math.Random.secure();
    final nonce = base64Url.encode(
      List.generate(32, (_) => random.nextInt(256)),
    );
    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? _googleIosClientId
          : null,
      serverClientId: _googleWebClientId,
      nonce: sha256.convert(utf8.encode(nonce)).toString(),
    );
    return SupabaseAccounts._(nonce);
  }

  @override
  bool get canUseGoogle => GoogleSignIn.instance.supportsAuthenticate();

  @override
  Account? get current => _toAccount(_client.auth.currentUser);

  @override
  Future<Account?> signInWithGoogle() async {
    final GoogleSignInAccount google;
    try {
      google = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AccountException(_googleProblem(e));
    }
    final idToken = google.authentication.idToken;
    if (idToken == null) {
      throw const AccountException('Google didn\'t sign you in. Try again.');
    }
    try {
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        nonce: _nonce,
      );
      final account = _toAccount(response.user);
      if (account == null) {
        throw const AccountException('Couldn\'t sign in. Try again.');
      }
      return Account(
        id: account.id,
        email: account.email,
        firstName: account.firstName.isNotEmpty
            ? account.firstName
            : firstNameOf(google.displayName ?? ''),
      );
    } on AuthException catch (e) {
      debugPrint('Supabase sign-in failed: ${e.message}');
      await GoogleSignIn.instance.signOut();
      throw const AccountException(
        'Couldn\'t sign in right now. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException {
      // Already signed out on the server; the local session is gone anyway.
    }
    await GoogleSignIn.instance.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account', method: HttpMethod.post);
    } on FunctionException catch (e) {
      debugPrint('delete-account failed: ${e.status} ${e.details}');
      throw const AccountException(
        'Couldn\'t delete your account right now. Check your connection '
        'and try again.',
      );
    } on Exception {
      throw const AccountException(
        'Couldn\'t reach Runway. Check your connection and try again.',
      );
    }
    // The server session died with the account; clear it here too.
    await _client.auth.signOut(scope: SignOutScope.local);
    await GoogleSignIn.instance.disconnect();
  }

  static Account? _toAccount(User? user) {
    if (user == null) return null;
    final meta = user.userMetadata ?? const {};
    final name = meta['full_name'] ?? meta['name'];
    return Account(
      id: user.id,
      email: user.email ?? '',
      firstName: name is String ? firstNameOf(name) : '',
    );
  }

  static String _googleProblem(GoogleSignInException e) {
    debugPrint('Google sign-in failed: ${e.code} ${e.description}');
    return switch (e.code) {
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in isn\'t available on this phone.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in isn\'t set up right for this build.',
      _ => 'Google didn\'t sign you in. Try again.',
    };
  }
}

/// Keeps the Supabase session in the Keychain / Keystore instead of plain
/// app preferences.
class _SecureSessionStorage extends LocalStorage {
  const _SecureSessionStorage();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    aOptions: AndroidOptions(resetOnError: false),
  );
  static const _key = 'supabase.session';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);

  @override
  Future<String?> accessToken() => _storage.read(key: _key);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
}
