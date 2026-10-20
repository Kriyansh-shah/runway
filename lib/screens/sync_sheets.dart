import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_sync.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/aurora_background.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/glass.dart';
import '../widgets/gradient_button.dart';
import '../widgets/ph_icons.dart';
import '../widgets/transitions.dart';
import 'setup_screen.dart';

/// Opens whatever fits sync's state: turn it on, unlock it on this device,
/// or manage it.
Future<void> showSyncSheet(BuildContext context) async {
  final state = AppScope.read(context);
  switch (state.sync.status) {
    case SyncStatus.off:
      return _showSheet(context, const _PassphraseSheet(startOver: false));
    case SyncStatus.needsPassphrase:
      return _showSheet(context, const _UnlockSheet());
    case SyncStatus.on:
      return _manage(context);
  }
}

/// What the sync row in Settings says.
String syncSummary(AppState state) {
  final sync = state.sync;
  if (sync.busy) return 'Syncing…';
  if (sync.error != null && sync.status == SyncStatus.on) return sync.error!;
  return switch (sync.status) {
    SyncStatus.off => 'Off. Turn on to see your budget on every device.',
    SyncStatus.needsPassphrase =>
      'Your budget is synced. Enter your passphrase to use it here.',
    SyncStatus.on => switch (sync.lastSynced) {
      null => 'On',
      final at => 'On · synced ${_ago(state.now, at)}',
    },
  };
}

String _ago(DateTime now, DateTime at) {
  final minutes = now.difference(at).inMinutes;
  if (minutes < 1) return 'just now';
  if (minutes < 60) return '${plural(minutes, 'min')} ago';
  return shortDate(at);
}

Future<void> _showSheet(BuildContext context, Widget sheet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      elevation: 0,
      builder: (_) => sheet,
    );

Future<void> _manage(BuildContext context) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final choice = await showActionSheet<String>(
    context,
    title: 'Budget sync is on',
    message:
        'Your budget is encrypted with your passphrase before it leaves '
        'this device. Nobody else can read it, including Runway.',
    actions: const [
      SheetAction(value: 'now', label: 'Sync now', icon: PhIcons.repeat),
      SheetAction(
        value: 'stop',
        label: 'Stop syncing on this device',
        icon: PhIcons.stopCircle,
      ),
      SheetAction(
        value: 'delete',
        label: 'Delete the synced copy',
        icon: PhIcons.trash,
        destructive: true,
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'delete') {
    final sure = await showActionSheet<bool>(
      context,
      title: 'Delete the synced copy?',
      message:
          'Sync stops on all your devices. The budget on each device stays '
          'where it is.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete synced copy',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (sure != true) return;
  }
  try {
    switch (choice) {
      case 'now':
        await state.sync.check();
      case 'stop':
        await state.sync.turnOff(deleteCopy: false);
        messenger.showSnackBar(
          const SnackBar(content: Text('Sync is off on this device.')),
        );
      case 'delete':
        await state.sync.turnOff(deleteCopy: true);
        messenger.showSnackBar(
          const SnackBar(content: Text('The synced copy was deleted.')),
        );
    }
  } on SyncException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

/// Picks a passphrase: to turn sync on, or (with [startOver]) to replace a
/// synced copy whose passphrase is forgotten.
class _PassphraseSheet extends StatefulWidget {
  const _PassphraseSheet({required this.startOver});
  final bool startOver;

  @override
  State<_PassphraseSheet> createState() => _PassphraseSheetState();
}

class _PassphraseSheetState extends State<_PassphraseSheet> {
  final _first = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _first.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem =
        validatePassphrase(_first.text) ??
        (_first.text != _again.text ? 'The passphrases don\'t match.' : null);
    if (problem != null) {
      HapticFeedback.heavyImpact();
      setState(() => _problem = problem);
      return;
    }
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      if (widget.startOver) {
        await state.sync.startOver(_first.text);
      } else {
        await state.sync.turnOn(_first.text);
      }
      HapticFeedback.mediumImpact();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Budget sync is on.')),
      );
    } on SyncException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      children: [
        Text(
          widget.startOver ? 'Start sync over' : 'Sync your budget',
          style: AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.startOver
              ? 'The old synced copy is deleted, and this device\'s budget '
                    'is synced again with a new passphrase.'
              : 'Sign in on another device and your budget is there. It\'s '
                    'locked with a passphrase only you know, so nobody else '
                    'can read it, including Runway.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _first,
          hint: 'New passphrase (8+ characters)',
          icon: PhIcons.lock,
          obscureText: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        GlassTextField(
          controller: _again,
          hint: 'Type it again',
          icon: PhIcons.lock,
          obscureText: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: 10),
        Text(
          _problem ??
              '⚠️ Write it down. If you forget it, the synced copy can\'t be '
                  'opened; the budget on this device is still fine.',
          style: AppText.label.copyWith(
            color: _problem == null ? AppColors.butter : AppColors.red,
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: _busy
              ? 'Uploading…'
              : widget.startOver
              ? 'Start over'
              : 'Turn on sync',
          icon: PhIcons.lock,
          onTap: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Unlocks the account's synced budget on this device and brings it here.
/// With [restore], it's the full-screen version shown on a fresh device
/// before setup.
class _UnlockForm extends StatefulWidget {
  const _UnlockForm({required this.onDone, this.restore = false});

  /// Called after the budget arrived (or on "Start fresh instead").
  final VoidCallback onDone;
  final bool restore;

  @override
  State<_UnlockForm> createState() => _UnlockFormState();
}

class _UnlockFormState extends State<_UnlockForm> {
  final _passphrase = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _passphrase.text.isEmpty) return;
    final state = AppScope.read(context);
    FocusScope.of(context).unfocus();
    if (!state.needsSetup) {
      final ok = await showActionSheet<bool>(
        context,
        title: 'Replace this device\'s budget?',
        message:
            'The synced budget replaces what\'s on this device now. Changes '
            'made here that never synced are lost.',
        actions: const [
          SheetAction(
            value: true,
            label: 'Use the synced budget',
            icon: PhIcons.checkCircle,
          ),
        ],
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await state.sync.unlock(_passphrase.text);
      HapticFeedback.mediumImpact();
      if (mounted) widget.onDone();
    } on WrongPassphraseException {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'That passphrase didn\'t open it. Try again.';
        });
      }
    } on SyncException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e.message;
        });
      }
    }
  }

  Future<void> _forgot() async {
    final ok = await showActionSheet<bool>(
      context,
      title: 'Forgot your passphrase?',
      message:
          'Nobody can open the synced copy without it, not even Runway. You '
          'can delete it and sync this device\'s budget with a new '
          'passphrase instead.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete it and start over',
          icon: PhIcons.trash,
          destructive: true,
        ),
      ],
    );
    if (ok != true || !mounted) return;
    await _showSheet(context, const _PassphraseSheet(startOver: true));
    if (mounted && AppScope.read(context).sync.status == SyncStatus.on) {
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.restore ? 'Welcome back 👋' : 'Bring your budget here',
          style: widget.restore ? AppText.title : AppText.heading,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.restore
              ? 'Your budget is synced from another device. Enter your sync '
                    'passphrase to bring it here.'
              : 'Enter the passphrase you chose when you turned on sync.',
          style: AppText.label,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _passphrase,
          hint: 'Sync passphrase',
          icon: PhIcons.lock,
          obscureText: true,
          maxLength: 200,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _unlock(),
        ),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _problem!,
              style: AppText.label.copyWith(color: AppColors.red),
            ),
          ),
        const SizedBox(height: 16),
        GradientButton(
          label: _busy ? 'Unlocking…' : 'Unlock my budget',
          icon: PhIcons.lock,
          onTap: _busy ? null : _unlock,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _busy ? null : _forgot,
          child: Text('Forgot it?', style: AppText.label),
        ),
        if (widget.restore)
          TextButton(
            onPressed: _busy ? null : widget.onDone,
            child: Text(
              'Start fresh on this device instead',
              style: AppText.label,
            ),
          ),
      ],
    );
  }
}

class _UnlockSheet extends StatelessWidget {
  const _UnlockSheet();

  @override
  Widget build(BuildContext context) {
    return SheetFrame(
      children: [_UnlockForm(onDone: () => Navigator.of(context).pop())],
    );
  }
}

/// A fresh device signed in to an account with a synced budget: unlock it
/// before setup, or start fresh.
class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context);
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GlassCard(
                  strong: true,
                  radius: 28,
                  padding: const EdgeInsets.all(20),
                  child: _UnlockForm(
                    restore: true,
                    onDone: () => Navigator.of(context).pushReplacement(
                      FadeScaleRoute<void>(
                        builder: (_) => state.needsSetup
                            ? const SetupScreen()
                            : landingFor(state),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
