import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/theme.dart';
import '../widgets/glass.dart';
import '../widgets/mochi.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'shell.dart';
import 'split_bill_sheet.dart';
import '../widgets/ph_icons.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Squad', style: AppText.title),
      ),
      _PetCard(mood: state.mood, level: state.petLevel, streak: state.streak),
      _ChallengeCard(state: state),
      _Leaderboard(state: state),
      _Splits(splits: state.splits),
    ];
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, navClearance(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Entrance(index: i, child: sections[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({
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

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('You', '😎', state.myNoDeliveryDays),
      for (final f in state.friends) (f.name, f.emoji, f.noDeliveryDays),
    ];
    final day = state.challengeDay.clamp(1, 7);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📦', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Text('No-delivery week', style: AppText.heading)),
              Pill(label: 'Day $day of 7', color: AppColors.lime),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cook, walk, or pick it up. Save ~${money(deliverySavings, cents: false)} each.',
            style: AppText.label,
          ),
          const SizedBox(height: 14),
          for (final (name, emoji, days) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Text(
                      name,
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  for (var i = 0; i < 7; i++)
                    _Dot(
                      state: i < days.length ? (days[i] ? 1 : -1) : 0,
                      index: i,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Rough weekly saving from skipping delivery, for the subtitle.
  static double get deliverySavings =>
      ExpensePreset.all
          .firstWhere((p) => p.category == ExpenseCategory.delivery)
          .amount *
      3;
}

/// 1 = made it, -1 = slipped, 0 = upcoming.
class _Dot extends StatelessWidget {
  const _Dot({required this.state, required this.index});
  final int state;
  final int index;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      1 => AppColors.lime,
      -1 => AppColors.red,
      _ => Colors.transparent,
    };
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Motion.med + Motion.stagger * index,
        curve: Motion.spring,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == 0 ? null : color.withValues(alpha: 0.85),
            border: Border.all(
              color: state == 0 ? AppColors.hairline : color,
              width: 1.5,
            ),
            boxShadow: state == 0
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: state == 0
              ? null
              : Icon(
                  state == 1 ? PhIcons.checkBold : PhIcons.xBold,
                  size: 12,
                  color: AppColors.bg,
                ),
        ),
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('You', '😎', state.streak, true),
      for (final f in state.friends) (f.name, f.emoji, f.streak, false),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Streak leaderboard',
          trailing: Text('🔒 streaks only, never \$', style: AppText.caption),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          ['🥇', '🥈', '🥉'].elementAtOrNull(i) ?? '${i + 1}',
                          style: AppText.number.copyWith(fontSize: 16),
                        ),
                      ),
                      Text(entries[i].$2, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entries[i].$1,
                          style: AppText.body.copyWith(
                            fontWeight: entries[i].$4
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('🔥 ', style: const TextStyle(fontSize: 14)),
                      Text(
                        '${entries[i].$3}',
                        style: AppText.number.copyWith(
                          fontSize: 17,
                          color: entries[i].$4
                              ? AppColors.butter
                              : AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Splits extends StatelessWidget {
  const _Splits({required this.splits});
  final List<BillSplit> splits;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Roommate splits',
          trailing: Pressable(
            onTap: () => showSplitBillSheet(context),
            semanticLabel: 'Split a bill',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: AppGradients.brand,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.28),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhIcons.plusBold,
                    size: 16,
                    color: AppColors.onLime,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Split a bill',
                    style: AppText.label.copyWith(
                      color: AppColors.onLime,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.med,
          child: splits.isEmpty
              ? GlassCard(
                  key: const ValueKey('empty'),
                  child: Center(
                    child: Text(
                      'All square ✨  Paid for something shared? Split it.',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: AppColors.lime),
                    ),
                  ),
                )
              : Column(
                  key: const ValueKey('list'),
                  children: [
                    // Keyed so a freshly split bill animates in.
                    for (final s in splits)
                      Entrance(
                        key: ValueKey(s.id),
                        index: 0,
                        child: _SplitRow(split: s),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SplitRow extends StatefulWidget {
  const _SplitRow({required this.split});
  final BillSplit split;

  @override
  State<_SplitRow> createState() => _SplitRowState();
}

class _SplitRowState extends State<_SplitRow>
    with SingleTickerProviderStateMixin {
  bool _settled = false;
  late final _collapse = AnimationController(
    vsync: this,
    duration: Motion.med,
    value: 1,
  );

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  Future<void> _settle() async {
    if (_settled) return;
    HapticFeedback.mediumImpact();
    setState(() => _settled = true);
    final state = AppScope.read(context);
    await Future<void>.delayed(const Duration(milliseconds: 750));
    if (!mounted) return;
    await _collapse.animateTo(0, curve: Motion.out);
    if (!mounted) return;
    state.settleSplit(widget.split.id);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.split;
    final color = s.theyOweYou ? AppColors.lime : AppColors.red;
    return SizeTransition(
      sizeFactor: _collapse,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _collapse,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          style: AppText.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          children: s.theyOweYou
                              ? [
                                  TextSpan(text: '${s.person} owes you '),
                                  TextSpan(
                                    text: money(s.amount),
                                    style: TextStyle(color: color),
                                  ),
                                ]
                              : [
                                  TextSpan(text: 'You owe ${s.person} '),
                                  TextSpan(
                                    text: money(s.amount),
                                    style: TextStyle(color: color),
                                  ),
                                ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(s.note, style: AppText.label),
                    ],
                  ),
                ),
                Pressable(
                  onTap: _settled ? null : _settle,
                  child: AnimatedContainer(
                    duration: Motion.med,
                    curve: Motion.out,
                    width: _settled ? 44 : 104,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: _settled
                          ? AppGradients.hot
                          : AppGradients.brand,
                      boxShadow: [
                        BoxShadow(
                          color: (_settled ? AppColors.lilac : AppColors.lime)
                              .withValues(alpha: 0.3),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: Motion.fast,
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: _settled
                          ? const Icon(
                              PhIcons.checkBold,
                              key: ValueKey(1),
                              color: AppColors.bg,
                            )
                          : Text(
                              'Settle up',
                              key: const ValueKey(0),
                              maxLines: 1,
                              style: AppText.label.copyWith(
                                color: AppColors.onLime,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
