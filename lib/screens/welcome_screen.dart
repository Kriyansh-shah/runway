import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/auth.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/glass.dart';
import '../widgets/google_button.dart';
import '../widgets/mochi_takeoff.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'setup_screen.dart';
import '../widgets/ph_icons.dart';

enum _Phase { idle, success }

/// First screen on a fresh install (or after erasing everything): asks only
/// for a name, or signs in with Google where that's set up. No passwords;
/// the money data never leaves the phone, and the optional app lock
/// protects it.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.playIntro = false});

  /// Play "Mochi's Takeoff" first (app launch). Skipped after erasing
  /// everything or when the phone asks for reduced motion.
  final bool playIntro;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _buttonKey = GlobalKey();
  final _googleKey = GlobalKey();
  final _logoKey = GlobalKey();
  final _stackKey = GlobalKey();

  /// Intro clock in seconds; drives the login card rising in.
  late final _introTime = ValueNotifier<double>(
    widget.playIntro ? 0 : kTakeoffEnd,
  );
  late bool _introRunning = widget.playIntro;

  _Phase _phase = _Phase.idle;
  String? _error;

  /// Google's account picker is open or the sign-in is finishing.
  bool _googleBusy = false;
  String? _googleError;

  /// Horizontal shake when the name is missing.
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// Pushes the welcome content back while the next screen is revealed.
  late final _exit = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void dispose() {
    _name.dispose();
    _introTime.dispose();
    _shake.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introRunning && MediaQuery.disableAnimationsOf(context)) {
      _introRunning = false;
      _introTime.value = kTakeoffEnd;
    }
  }

  /// Where the intro's logo must land: exactly on the header's [LogoMark].
  Offset _logoBaseline(Size size) {
    final header = _logoKey.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (header == null || stack == null || !header.hasSize) {
      return Offset(size.width / 2, size.height * 0.22);
    }
    return stack.globalToLocal(header.localToGlobal(LogoMark.baseline));
  }

  Future<void> _submit() async {
    if (_phase != _Phase.idle || _googleBusy) return;
    final error = validateName(_name.text);
    if (error != null) {
      HapticFeedback.heavyImpact();
      setState(() => _error = error);
      _shake.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    final state = AppScope.read(context);
    final user = UserProfile(name: _name.text.trim());
    HapticFeedback.mediumImpact();
    setState(() {
      _error = null;
      _phase = _Phase.success;
    });
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    state.signedIn(user);
    await _reveal(_buttonKey);
  }

  Future<void> _continueWithGoogle() async {
    if (_phase != _Phase.idle || _googleBusy) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    final state = AppScope.read(context);
    setState(() {
      _googleBusy = true;
      _googleError = null;
    });
    try {
      final signedIn = await state.signInWithGoogle();
      if (!mounted) return;
      if (!signedIn) {
        setState(() => _googleBusy = false);
        return;
      }
    } on AccountException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _googleBusy = false;
        _googleError = e.message;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    await _reveal(_googleKey);
  }

  /// Opens the next screen in a circle growing from the button at [from].
  Future<void> _reveal(GlobalKey from) async {
    final state = AppScope.read(context);
    final box = from.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null
        ? MediaQuery.sizeOf(context).center(Offset.zero)
        : box.localToGlobal(box.size.center(Offset.zero));
    _exit.forward();
    await Navigator.of(context).pushReplacement(
      CircularRevealRoute<void>(
        center: center,
        builder: (_) => landingFor(state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase != _Phase.idle || _googleBusy;
    final google = AppScope.read(context).accounts.canUseGoogle;
    final where = kIsWeb ? 'in this browser' : 'on this phone';
    final sections = <Widget>[
      // The intro hands its logo over to this exact spot when it ends.
      Center(
        child: SizedBox.fromSize(
          key: _logoKey,
          size: LogoMark.size,
          child: _introRunning ? null : const LogoMark(),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Make your money last the whole semester.',
        style: AppText.body.copyWith(color: AppColors.muted),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      AnimatedBuilder(
        animation: _shake,
        builder: (context, child) {
          final t = _shake.value;
          final dx = math.sin(t * math.pi * 5) * 10 * (1 - t);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: GlassCard(
          strong: true,
          radius: 28,
          padding: const EdgeInsets.all(18),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassTextField(
                  controller: _name,
                  hint: 'Your first name',
                  icon: PhIcons.user,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  autofillHints: const [AutofillHints.givenName],
                  maxLength: 30,
                ),
                AnimatedSize(
                  duration: Motion.med,
                  curve: Motion.out,
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity, height: 16)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Row(
                            children: [
                              const Icon(
                                PhIcons.warningCircle,
                                size: 16,
                                color: AppColors.red,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppText.label.copyWith(
                                    color: AppColors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: _MorphButton(
                    key: _buttonKey,
                    phase: _phase,
                    label: 'Get started',
                    onTap: busy ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (google) ...[
        const SizedBox(height: 16),
        const _OrDivider(),
        const SizedBox(height: 16),
        GoogleButton(
          key: _googleKey,
          busy: _googleBusy,
          onTap: busy ? null : _continueWithGoogle,
        ),
        if (_googleError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _googleError!,
              style: AppText.label.copyWith(color: AppColors.red),
              textAlign: TextAlign.center,
            ),
          ),
      ],
      const SizedBox(height: 20),
      Text(
        google
            ? '🔒 No bank linking. Your money data stays $where, even when '
                  'you sign in.'
            : '🔒 No account, no bank linking. Your money data stays $where.',
        style: AppText.caption.copyWith(fontSize: 12, letterSpacing: 0),
        textAlign: TextAlign.center,
      ),
    ];

    var rise = 0;
    final content = AuroraBackground(
      child: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) {
          final t = Curves.easeInCubic.transform(_exit.value);
          return Opacity(
            opacity: 1 - 0.6 * t,
            child: Transform.scale(scale: 1 - 0.08 * t, child: child),
          );
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sections.length; i++)
                      if (sections[i] is SizedBox || i == 0)
                        sections[i]
                      else if (widget.playIntro)
                        _IntroRise(
                          time: _introTime,
                          index: rise++,
                          child: sections[i],
                        )
                      else
                        Entrance(index: i, child: sections[i]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        key: _stackKey,
        children: [
          Positioned.fill(child: content),
          if (_introRunning)
            Positioned.fill(
              child: MochiTakeoff(
                logoBaseline: _logoBaseline,
                onTime: (t) => _introTime.value = t,
                onFinished: () => setState(() => _introRunning = false),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rises a welcome section in with the intro's clock, staggered by [index].
class _IntroRise extends StatelessWidget {
  const _IntroRise({
    required this.time,
    required this.index,
    required this.child,
  });

  final ValueListenable<double> time;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: child,
      builder: (context, t, child) {
        final start = 3.6 + index * 0.07;
        final p = Curves.easeOutCubic.transform(
          ((t - start) / 0.5).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: p,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - p)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Gradient CTA that morphs: full-width label → mint check.
class _MorphButton extends StatelessWidget {
  const _MorphButton({
    super.key,
    required this.phase,
    required this.label,
    required this.onTap,
  });

  final _Phase phase;
  final String label;
  final VoidCallback? onTap;

  static const _height = 56.0;

  @override
  Widget build(BuildContext context) {
    final idle = phase == _Phase.idle;
    final success = phase == _Phase.success;
    final glow = success ? AppColors.lime : AppColors.lilac;
    return LayoutBuilder(
      builder: (context, c) => Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: Motion.med,
          curve: Curves.easeInOutCubic,
          width: idle ? c.maxWidth : _height,
          height: _height,
          decoration: BoxDecoration(
            gradient: success ? AppGradients.good : AppGradients.brand,
            borderRadius: BorderRadius.circular(_height / 2),
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.5),
                blurRadius: success ? 30 : 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Motion.spring),
                child: child,
              ),
            ),
            child: switch (phase) {
              _Phase.idle => Text(
                label,
                key: const ValueKey('label'),
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: AppText.heading.copyWith(color: AppColors.onLime),
              ),
              _Phase.success => const Icon(
                PhIcons.checkBold,
                key: ValueKey('done'),
                color: AppColors.bg,
                size: 28,
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// "or" between the name card and the Google button.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(child: Divider(color: AppColors.hairline));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: AppText.label),
        ),
        line,
      ],
    );
  }
}
