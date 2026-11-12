import 'package:flutter/material.dart';

import '../app/budget_math.dart';
import '../app/theme.dart';
import 'glass.dart';
import 'mochi.dart';

/// Mochi, your money pet: its mood and level, from your logging streak.
/// On the Squad tab when squads are on, otherwise on Home.
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.mood,
    required this.level,
    required this.streak,
  });
  final PetMood mood;
  final PetLevel level;
  final int streak;

  Color get _moodColor => switch (mood) {
    PetMood.thriving => AppColors.lime,
    PetMood.chill => AppColors.lilac,
    PetMood.worried => AppColors.butter,
  };

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          Mochi(mood: mood, size: 120),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Mochi',
                      style: AppText.heading.copyWith(fontSize: 22),
                    ),
                    Pill(
                      label: '${mood.emoji} ${mood.label}',
                      color: _moodColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    GradientText('Lv ${level.level}', style: AppText.number),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${level.xp}/${level.xpForNext} XP',
                        style: AppText.caption,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _XpBar(progress: level.progress),
                const SizedBox(height: 10),
                Text(
                  '🔥 $streak-day streak · log daily to level up',
                  style: AppText.label.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: Motion.slow,
        curve: Motion.out,
        builder: (context, v, _) => FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: v.clamp(0.02, 1.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.brand,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lime.withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
