import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'pressable.dart';

/// Icon tile, title and subtitle, then an amount. Tappable when [onTap] is set.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.accent,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final String amount;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = _content();
    if (onTap == null) return row;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: '$title, $amount, $subtitle',
      child: row,
    );
  }

  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairline),
            ),
            child: leading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.caption.copyWith(
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (accent != null)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: accent!, blurRadius: 6)],
              ),
            ),
          Text(amount, style: AppText.number.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}
