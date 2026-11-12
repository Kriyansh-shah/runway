/// Logging by voice from outside the app on Android: the "Log expense"
/// Quick Settings tile and a pinned "Log by voice" home-screen icon, both
/// through android/.../QuickLog.kt. Either opens Quick Add already
/// listening, through [AppState.voiceAddRequested]. (On iPhone, Siri does
/// this; the long-press "Log by voice" shortcut is in main.dart.)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How asking the system to add the tile went.
enum TileRequest { added, alreadyAdded, notAdded, unsupported }

abstract interface class QuickLogShortcuts {
  bool get supported;

  /// Android 13+ can add the tile with one tap; older phones add it by
  /// editing the Quick Settings panel.
  Future<bool> canAddTile();
  Future<TileRequest> addTile();

  /// Whether the home screen takes pinned icons.
  Future<bool> canPinShortcut();

  /// True if the launcher was asked; it shows its own confirmation.
  Future<bool> pinShortcut();
}

class NoQuickLog implements QuickLogShortcuts {
  const NoQuickLog();

  @override
  bool get supported => false;

  @override
  Future<bool> canAddTile() async => false;

  @override
  Future<TileRequest> addTile() async => TileRequest.unsupported;

  @override
  Future<bool> canPinShortcut() async => false;

  @override
  Future<bool> pinShortcut() async => false;
}

class AndroidQuickLog implements QuickLogShortcuts {
  AndroidQuickLog._();

  static const _channel = MethodChannel('runway/quick_log');

  static bool get available =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Calls [onVoiceAdd] if the tile or icon opened the app, and whenever
  /// either is tapped while it's open.
  static Future<AndroidQuickLog> start(VoidCallback onVoiceAdd) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'voiceAdd') onVoiceAdd();
    });
    try {
      if (await _channel.invokeMethod<bool>('take') ?? false) onVoiceAdd();
    } on PlatformException catch (e) {
      debugPrint('Quick log unavailable: ${e.message}');
    }
    return AndroidQuickLog._();
  }

  @override
  bool get supported => true;

  Future<bool> _ask(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (e) {
      debugPrint('Quick log $method failed: ${e.message}');
      return false;
    }
  }

  @override
  Future<bool> canAddTile() => _ask('canAddTile');

  @override
  Future<TileRequest> addTile() async {
    try {
      final result = await _channel.invokeMethod<String>('addTile');
      return TileRequest.values.asNameMap()[result] ?? TileRequest.unsupported;
    } on PlatformException catch (e) {
      debugPrint('Quick log addTile failed: ${e.message}');
      return TileRequest.unsupported;
    }
  }

  @override
  Future<bool> canPinShortcut() => _ask('canPinShortcut');

  @override
  Future<bool> pinShortcut() => _ask('pinShortcut');
}
