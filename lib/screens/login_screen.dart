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
import '../widgets/mochi_takeoff.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import '../widgets/transitions.dart';
import 'shell.dart';
import '../widgets/ph_icons.dart';

enum _Phase { idle, loading, success }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.playIntro = false});

  /// Play "Mochi's Takeoff" first (app launch). Skipped when signing out
  /// or when the phone asks for reduced motion.
  final bool playIntro;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _buttonKey = GlobalKey();
  final _logoKey = GlobalKey();
  final _stackKey = GlobalKey();

  /// Intro clock in seconds; drives the login card rising in.
  late final _introTime = ValueNotifier<double>(
    widget.playIntro ? 0 : kTakeoffEnd,
  );
  late bool _introRunning = widget.playIntro;

  bool _signUp = false;
  bool _showPassword = false;
  _Phase _phase = _Phase.idle;
  String? _error;

  /// Horizontal shake when credentials are rejected.
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// Pushes the login content back while the next screen is revealed.
  late final _exit = AnimationController(vsync: this, duration: Motion.slow);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
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

  void _setMode(bool signUp) {
    if (signUp == _signUp || _phase != _Phase.idle) return;
    HapticFeedback.selectionClick();
    setState(() {
      _signUp = signUp;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_phase != _Phase.idle) return;
    FocusScope.of(context).unfocus();
    final state = AppScope.read(context);
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });

    final UserProfile user;
    try {
      user = _signUp
          ? await state.auth.signUp(
              name: _name.text,
              email: _email.text,
              password: _password.text,
            )
          : await state.auth.signIn(
              email: _email.text,
              password: _password.text,
            );
    } on AuthException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _phase = _Phase.idle;
        _error = e.message;
      });
      _shake.forward(from: 0);
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.success);
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final center = box == null
        ? MediaQuery.sizeOf(context).center(Offset.zero)
        : box.localToGlobal(box.size.center(Offset.zero));
    state.signedIn(user);
    _exit.forward();
    await Navigator.of(context).pushReplacement(
      CircularRevealRoute<void>(center: center, builder: (_) => const Shell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _phase != _Phase.idle;
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
                _ModeToggle(signUp: _signUp, onChanged: _setMode),
                const SizedBox(height: 16),
                AnimatedSize(
                  duration: Motion.med,
                  curve: Motion.out,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: Motion.med,
                    child: _signUp
                        ? Padding(
                            key: const ValueKey('name'),
                            padding: const EdgeInsets.only(bottom: 12),
                            child: GlassTextField(
                              controller: _name,
                              hint: 'Your first name',
                              icon: PhIcons.user,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.givenName],
                            ),
                          )
                        : const SizedBox(
                            key: ValueKey('none'),
                            width: double.infinity,
                          ),
                  ),
                ),
                GlassTextField(
                  controller: _email,
                  hint: 'you@uni.edu',
                  icon: PhIcons.at,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  maxLength: 80,
                ),
                const SizedBox(height: 12),
                GlassTextField(
                  controller: _password,
                  hint: 'Password',
                  icon: PhIcons.lock,
                  obscureText: !_showPassword,
                  textCapitalization: TextCapitalization.none,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  autofillHints: [
                    _signUp
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  maxLength: 64,
                  suffix: Pressable(
                    onTap: () => setState(() => _showPassword = !_showPassword),
                    semanticLabel: _showPassword
                        ? 'Hide password'
                        : 'Show password',
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        child: Icon(
                          _showPassword ? PhIcons.eyeSlash : PhIcons.eye,
                          key: ValueKey(_showPassword),
                          size: 20,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
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
                    label: _signUp ? 'Create account' : 'Sign in',
                    onTap: busy ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text(
        '🔒 No bank linking. Your money data stays on this device.',
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

/// Rises a login section in with the intro's clock, staggered by [index].
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

/// Sign in / Create account segmented control with a sliding pill.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.signUp, required this.onChanged});
  final bool signUp;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: signUp ? Alignment.centerRight : Alignment.centerLeft,
            duration: Motion.med,
            curve: Motion.spring,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.hairline),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final up in [false, true])
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(up),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.fast,
                        style: AppText.label.copyWith(
                          color: up == signUp
                              ? AppColors.text
                              : AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                        child: Text(up ? 'Create account' : 'Sign in'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Gradient CTA that morphs: full-width label → spinner circle → mint check.
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
              _Phase.loading => const SizedBox.square(
                key: ValueKey('spin'),
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.onLime,
                ),
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
