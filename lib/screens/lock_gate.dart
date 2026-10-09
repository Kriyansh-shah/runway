import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/device_auth.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/mochi_takeoff.dart';
import '../widgets/ph_icons.dart';

/// Sits above every screen (and every sheet) of the app:
///
/// * Covers the app whenever it leaves the foreground, so balances never
///   show in the app switcher's snapshot.
/// * With the app lock on, asks for Face ID / passcode on launch and after
///   [timeout] away. Screens stay mounted underneath, so nothing is lost.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  /// How long the app can be away before it locks again.
  static const timeout = Duration(minutes: 1);

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late final AppState _state = AppScope.read(context);
  late bool _locked = _shouldLock;
  bool _covered = false;
  bool _checking = false;
  DateTime? _awaySince;

  bool get _shouldLock => _state.appLockEnabled && _state.user != null;

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) _unlockAfterFrame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    switch (lifecycle) {
      // Inactive comes first and is when iOS takes the switcher snapshot.
      // (The Face ID prompt itself also makes the app inactive; that's
      // fine, the cover sits under the prompt.) On desktop, inactive only
      // means another window has focus, so the app stays visible.
      case AppLifecycleState.inactive:
        if (_isPhone) setState(() => _covered = true);
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        _awaySince ??= _state.now;
        setState(() => _covered = true);
      case AppLifecycleState.resumed:
        final away = _awaySince;
        _awaySince = null;
        final lockNow =
            !_locked &&
            _shouldLock &&
            away != null &&
            _state.now.difference(away) >= LockGate.timeout;
        setState(() {
          _covered = false;
          if (lockNow) _locked = true;
        });
        if (lockNow) _unlockAfterFrame();
      case AppLifecycleState.detached:
    }
  }

  void _unlockAfterFrame() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_unlock()));

  Future<void> _unlock() async {
    if (_checking || !_locked) return;
    setState(() => _checking = true);
    final result = await _state.deviceAuth.authenticate(
      'Unlock Runway to see your budget',
    );
    if (!mounted) return;
    setState(() {
      _checking = false;
      // No passcode on the phone any more: there's nothing to check
      // against, and refusing would lock the owner out of their own data.
      if (result != DeviceAuthResult.failed) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hidden = _locked || _covered;
    return Stack(
      children: [
        // Keep the screens mounted, but silent: no taps, no screen reader,
        // no animations while hidden.
        Positioned.fill(
          child: ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: TickerMode(enabled: !hidden, child: widget.child),
            ),
          ),
        ),
        if (_locked)
          Positioned.fill(
            child: _LockScreen(checking: _checking, onUnlock: _unlock),
          )
        else if (_covered)
          const Positioned.fill(child: _PrivacyCover()),
      ],
    );
  }
}

/// Plain branded cover for the app switcher.
class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bg,
      child: Center(child: LogoMark()),
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.checking, required this.onUnlock});

  final bool checking;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),
                const LogoMark(),
                const SizedBox(height: 28),
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: const Icon(
                    PhIcons.lock,
                    size: 28,
                    color: AppColors.lime,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Runway is locked', style: AppText.title),
                const SizedBox(height: 6),
                Text(
                  'Use $deviceLockName to open it.',
                  style: AppText.label,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GradientButton(
                    label: checking ? 'Checking…' : 'Unlock',
                    icon: PhIcons.lock,
                    onTap: checking ? null : onUnlock,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
