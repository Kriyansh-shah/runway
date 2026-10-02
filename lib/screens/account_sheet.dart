import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/gradient_button.dart';
import '../widgets/transitions.dart';
import 'login_screen.dart';

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (_) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  Future<void> _signOut(BuildContext context) async {
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    navigator.pop();
    await state.signOut();
    await navigator.pushAndRemoveUntil(
      FadeScaleRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AppScope.of(context).user;
    if (user == null) return const SizedBox.shrink();
    return SheetFrame(
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
            ),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
              ),
              child: Text(user.initial, style: AppText.title),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(user.name, style: AppText.title, textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(user.email, style: AppText.label, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'On-device account · nothing leaves your phone',
          style: AppText.caption.copyWith(letterSpacing: 0),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        GradientButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          gradient: AppGradients.hot,
          glow: AppColors.pink,
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}
