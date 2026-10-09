/// The phone's own owner check (Face ID, Touch ID, fingerprint or passcode)
/// behind an interface, so the app lock can be tested without a device.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum DeviceAuthResult {
  /// The owner was verified.
  success,

  /// Cancelled or not recognised. Try again.
  failed,

  /// The phone can't check: no passcode set, or no support (web, tests).
  unavailable,
}

abstract interface class DeviceAuth {
  /// Whether this phone can verify its owner at all.
  Future<bool> isAvailable();

  /// Shows the system prompt with [reason] (shown by Face ID on iOS).
  Future<DeviceAuthResult> authenticate(String reason);
}

/// Face ID / Touch ID / passcode on Apple devices, biometrics or PIN on
/// Android, via `local_auth`. Falls back to the passcode when biometrics
/// fail, so a scratched sensor never locks you out.
class LocalDeviceAuth implements DeviceAuth {
  const LocalDeviceAuth();

  static final _auth = LocalAuthentication();

  /// Errors that mean the phone can't check, rather than "not you".
  static const _unavailableCodes = {
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.uiUnavailable,
  };

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<DeviceAuthResult> authenticate(String reason) async {
    if (kIsWeb) return DeviceAuthResult.unavailable;
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Survive the prompt sending the app to the background briefly.
        persistAcrossBackgrounding: true,
      );
      return ok ? DeviceAuthResult.success : DeviceAuthResult.failed;
    } on LocalAuthException catch (e) {
      return _unavailableCodes.contains(e.code)
          ? DeviceAuthResult.unavailable
          : DeviceAuthResult.failed;
    } on MissingPluginException {
      return DeviceAuthResult.unavailable;
    } on PlatformException {
      return DeviceAuthResult.failed;
    }
  }
}

/// What the lock is called on this platform, for labels.
String get deviceLockName => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.macOS => 'Face ID, Touch ID or passcode',
  _ => 'Fingerprint, face or PIN',
};
