/// Siri's side of Runway (ios/Runner/VoiceLog.swift). Expenses said to
/// Siri wait on the phone until the app opens or comes back, for
/// [AppState.addSpokenExpenses]; and the app leaves Siri a copy of the
/// budget's numbers ([AppState.siriSummary]) so it can answer "how much
/// can I spend today?" without opening.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One thing said to Siri: how much, everything that was said ("8 bucks on
/// coffee", or just "Chipotle" when Apple Intelligence cleaned it up),
/// when, an [ExpenseCategory] name if one was picked ("Log coffee in
/// Runway"), and the name of one of the person's own categories if Apple
/// Intelligence picked that.
typedef VoiceEntry = ({
  double amount,
  String what,
  DateTime at,
  String? category,
  String? custom,
});

class VoiceInbox {
  const VoiceInbox();

  static const _channel = MethodChannel('runway/voice');

  /// Only the iPhone app has Siri; the web and Android don't.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Everything waiting, oldest first. The inbox is empty afterwards, so
  /// each one is handed over once.
  Future<List<VoiceEntry>> take() async {
    if (!supported) return const [];
    try {
      final raw = await _channel.invokeListMethod<Object?>('take') ?? const [];
      return [
        for (final item in raw)
          if (item case {
            'amount': final num amount,
            'what': final String what,
            'at': final num at,
          })
            (
              amount: amount.toDouble(),
              what: what,
              at: DateTime.fromMillisecondsSinceEpoch(at.round()),
              category: item['category'] is String
                  ? item['category'] as String
                  : null,
              custom: item['custom'] is String
                  ? item['custom'] as String
                  : null,
            ),
      ];
    } on Object catch (e) {
      debugPrint('Siri inbox unavailable: $e');
      return const [];
    }
  }

  /// Leaves Siri the latest numbers; null clears them (before setup).
  Future<void> share(Map<String, Object?>? summary) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod<void>(
        'share',
        summary == null ? null : jsonEncode(summary),
      );
    } on Object catch (e) {
      debugPrint('Siri summary not saved: $e');
    }
  }
}
