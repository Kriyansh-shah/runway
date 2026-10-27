import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'ph_icons.dart';

/// "Apple Intelligence" under words the on-device model wrote, so it's
/// clear when it answered and when the rules did.
class AiTag extends StatelessWidget {
  const AiTag({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(PhIcons.sparkle, size: 12, color: AppColors.lilac),
      const SizedBox(width: 4),
      Text(
        'Apple Intelligence',
        style: AppText.caption.copyWith(color: AppColors.lilac),
      ),
    ],
  );
}
