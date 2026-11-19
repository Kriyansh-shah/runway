import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// White "Continue with Apple" pill with Apple's logo, the style Apple's
/// Human Interface Guidelines give for dark backgrounds. Same size and
/// shape as the Google button, and shown above it.
class AppleButton extends StatelessWidget {
  const AppleButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Colors.black;
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Continue with Apple',
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: ink),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 20,
                    child: CustomPaint(painter: AppleLogoPainter(color: ink)),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Continue with Apple',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.heading.copyWith(color: ink, fontSize: 16),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
