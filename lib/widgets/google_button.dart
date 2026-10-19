import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// White "Continue with Google" pill, as Google's sign-in guidelines ask.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F1F1F);
    return Pressable(
      onTap: onTap,
      semanticLabel: 'Continue with Google',
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
                  Text(
                    'G',
                    style: AppText.heading.copyWith(
                      color: const Color(0xFF4285F4),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Continue with Google',
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
