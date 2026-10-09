import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'expense_inputs.dart';
import 'pressable.dart';

/// One choice in [showActionSheet].
class SheetAction<T> {
  const SheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Shown in red: deletes or erases something.
  final bool destructive;
}

/// A frosted sheet with a title, an optional explanation and a few choices.
/// Returns the chosen [SheetAction.value], or null if dismissed.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (context) => SheetFrame(
      children: [
        Text(title, style: AppText.heading, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message, style: AppText.label, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 16),
        for (final a in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActionRow(
              label: a.label,
              icon: a.icon,
              color: a.destructive ? AppColors.red : AppColors.text,
              onTap: () => Navigator.of(context).pop(a.value),
            ),
          ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppText.body.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
