import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_state.dart';
import '../app/auth.dart';
import '../app/budget_math.dart';
import '../app/format.dart';
import '../app/models.dart';
import '../app/squad.dart';
import '../app/theme.dart';
import '../widgets/action_sheet.dart';
import '../widgets/expense_inputs.dart';
import '../widgets/glass.dart';
import '../widgets/google_button.dart';
import '../widgets/gradient_button.dart';
import '../widgets/mochi.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'shell.dart';
import 'friends_sheets.dart';
import 'split_bill_sheet.dart';
import '../widgets/ph_icons.dart';

/// One person in the challenge and leaderboard: you or a friend.
typedef _Person = ({
  String name,
  String emoji,
  int streak,
  List<bool> days,
  bool isMe,
});

/// Your pet, your squad's challenge and streaks, and roommate splits.
/// Where sign-in is set up, the squad is real friends (names, streaks and
/// challenge dots only, never money); elsewhere it shows sample friends.
class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  @override
  void initState() {
    super.initState();
    // After the first frame: loading notifies listeners, which can't
    // happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      if (state.account != null) state.refreshSquad();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final me = (
      name: 'You',
      emoji: '😎',
      streak: state.streak,
      days: state.myNoDeliveryDays,
      isMe: true,
    );
    final squad = state.squad;
    final List<_Person>? people = !state.realSquad
        ? [
            me,
            for (final f in state.friends)
              (
                name: f.name,
                emoji: f.emoji,
                streak: f.streak,
                days: f.noDeliveryDays,
                isMe: false,
              ),
          ]
        : squad == null
        ? null
        : [
            for (final m in squad.members)
              m.isMe
                  ? me
                  : (
                      name: m.name,
                      emoji: m.emoji,
                      streak: m.streak,
                      days: m.noDeliveryDays,
                      isMe: false,
                    ),
          ];
    final sections = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('Squad', style: AppText.title),
      ),
      _PetCard(mood: state.mood, level: state.petLevel, streak: state.streak),
      if (state.realSquad)
        if (state.account == null)
          const _SquadSignIn()
        else ...[
          if (state.squads.isNotEmpty) const _SquadSwitcher(),
          if (squad != null)
            _SquadHeader(key: ValueKey(squad.id), squad: squad)
          else if (state.squadLoading)
            const _SquadLoading()
          else
            _StartOrJoin(error: state.squadError),
        ],
      if (people != null) ...[
        _ChallengeCard(state: state, people: people),
        _Leaderboard(people: people),
      ],
      if (state.realSquad && state.account != null) ...[
        if (squad != null && squad.simplifyDebts) _FewestPayments(squad: squad),
        const _FriendsCard(),
      ],
      _Splits(
        splits: state.splits,
        real: state.realSquad && state.account != null,
      ),
    ];
    final scroll = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
    );
    return SafeArea(
      bottom: false,
      child: state.account == null
          ? scroll
          : RefreshIndicator(
              color: AppColors.lime,
              backgroundColor: AppColors.bg,
              onRefresh: state.refreshSquad,
              child: scroll,
            ),
    );
  }
}

/// Signed out: Squad needs an account so friends can find each other.
class _SquadSignIn extends StatefulWidget {
  const _SquadSignIn();

  @override
  State<_SquadSignIn> createState() => _SquadSignInState();
}

class _SquadSignInState extends State<_SquadSignIn> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    if (_busy) return;
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (await state.signInWithGoogle()) HapticFeedback.mediumImpact();
    } on AccountException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Budget with your friends', style: AppText.heading),
          const SizedBox(height: 6),
          Text(
            'Start a squad with roommates or friends: streaks and challenges '
            'together. They see your first name and streak, never your money.',
            style: AppText.label,
          ),
          const SizedBox(height: 16),
          GoogleButton(busy: _busy, onTap: _busy ? null : _signIn),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: AppText.label.copyWith(color: AppColors.red),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _SquadLoading extends StatelessWidget {
  const _SquadLoading();

  @override
  Widget build(BuildContext context) {
    return const GlassCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.lime,
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed in but in no squad: start one, or join with a friend's code.
class _StartOrJoin extends StatefulWidget {
  const _StartOrJoin({this.error, this.onDone});

  /// Why loading the squad failed, if it did.
  final String? error;

  /// Called after starting or joining one (closes the sheet it's in).
  final VoidCallback? onDone;

  @override
  State<_StartOrJoin> createState() => _StartOrJoinState();
}

class _StartOrJoinState extends State<_StartOrJoin> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function(AppState state) action) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    String? problem;
    try {
      problem = await action(state);
    } on SquadException catch (e) {
      problem = e.message;
    }
    if (!mounted) return;
    if (problem == null) {
      HapticFeedback.mediumImpact();
      widget.onDone?.call();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _busy = false;
      _problem = problem;
    });
  }

  void _start() => _run((state) async {
    final problem = validateSquadName(_name.text);
    if (problem != null) return problem;
    await state.createSquad(_name.text.trim());
    return null;
  });

  void _join() => _run((state) async {
    if (cleanInviteCode(_code.text).length != 6) {
      return 'Invite codes are 6 letters and numbers.';
    }
    return await state.joinSquad(_code.text)
        ? null
        : 'That code didn\'t work. It may have expired; ask for a new one.';
  });

  @override
  Widget build(BuildContext context) {
    final problem = _problem ?? widget.error;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start a squad', style: AppText.heading),
          const SizedBox(height: 4),
          Text(
            'Up to $maxSquadSize friends. They see your first name and '
            'streak, never your money.',
            style: AppText.label,
          ),
          const SizedBox(height: 12),
          GlassTextField(
            controller: _name,
            hint: 'Squad name, e.g. Apt 4B',
            icon: PhIcons.usersThree,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _start(),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: 'Start squad',
            height: 50,
            onTap: _busy ? null : _start,
          ),
          const SizedBox(height: 20),
          Text('Have an invite code?', style: AppText.heading),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GlassTextField(
                  controller: _code,
                  hint: 'K7M2QX',
                  icon: PhIcons.at,
                  maxLength: 10,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _join(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: GradientButton(
                  label: 'Join',
                  height: 50,
                  gradient: AppGradients.hot,
                  glow: AppColors.lilac,
                  onTap: _busy ? null : _join,
                ),
              ),
            ],
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                problem,
                style: AppText.label.copyWith(color: AppColors.red),
              ),
            ),
        ],
      ),
    );
  }
}

/// Your squad's name and faces, with Invite and Leave.
class _SquadHeader extends StatefulWidget {
  const _SquadHeader({super.key, required this.squad});
  final Squad squad;

  @override
  State<_SquadHeader> createState() => _SquadHeaderState();
}

class _SquadHeaderState extends State<_SquadHeader> {
  final _inviteKey = GlobalKey();
  bool _busy = false;

  Future<void> _invite() async {
    if (_busy) return;
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final box = _inviteKey.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final code = await state.squadInviteCode();
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Join my squad "${widget.squad.name}" on Runway! Open Squad, '
              'tap "Have an invite code?" and enter $code',
          subject: 'Join my Runway squad',
          sharePositionOrigin: origin,
        ),
      );
    } on SquadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final alone = widget.squad.members.length <= 1;
    final ok = await showActionSheet<bool>(
      context,
      title: 'Leave ${widget.squad.name}?',
      message: alone
          ? 'You\'re the only one in it, so the squad is deleted.'
          : 'Your friends won\'t see your streak anymore. You can rejoin '
                'with a new invite code.',
      actions: const [
        SheetAction(
          value: true,
          label: 'Leave squad',
          icon: PhIcons.signOut,
          destructive: true,
        ),
      ],
    );
    if (ok != true) return;
    try {
      await state.leaveSquad();
    } on SquadException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final squad = widget.squad;
    final count = squad.members.length;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      squad.name,
                      style: AppText.heading.copyWith(fontSize: 20),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count == 1
                          ? 'Just you so far'
                          : '$count of $maxSquadSize people',
                      style: AppText.label,
                    ),
                  ],
                ),
              ),
              Pressable(
                onTap: _leave,
                semanticLabel: 'Leave squad',
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    PhIcons.signOut,
                    size: 20,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              for (final m in squad.members)
                Text(m.emoji, style: const TextStyle(fontSize: 24)),
            ],
          ),
          if (count > 1)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simplify debts', style: AppText.body),
                      Text(
                        'Settle the squad in the fewest payments.',
                        style: AppText.caption.copyWith(letterSpacing: 0),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: squad.simplifyDebts,
                  activeTrackColor: AppColors.lime,
                  onChanged: (on) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await AppScope.read(context).setSimplifyDebts(on);
                    } on SquadException catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(e.message)),
                      );
                    }
                  },
                ),
              ],
            ),
          if (count < maxSquadSize) ...[
            const SizedBox(height: 14),
            GradientButton(
              key: _inviteKey,
              label: _busy ? 'Getting a code…' : 'Invite friends',
              icon: PhIcons.plusBold,
              height: 50,
              onTap: _busy ? null : _invite,
            ),
          ],
        ],
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
  const _ChallengeCard({required this.state, required this.people});
  final AppState state;
  final List<_Person> people;

  @override
  Widget build(BuildContext context) {
    final rows = [for (final p in people) (p.name, p.emoji, p.days)];
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
  const _Leaderboard({required this.people});
  final List<_Person> people;

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final p in people) (p.name, p.emoji, p.streak, p.isMe),
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

/// A small lime pill button for section headers.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
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
            const Icon(PhIcons.plusBold, size: 16, color: AppColors.onLime),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppText.label.copyWith(
                color: AppColors.onLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Your squads side by side; tap one to see it, or start/join another.
class _SquadSwitcher extends StatelessWidget {
  const _SquadSwitcher();

  void _newSquad(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    elevation: 0,
    builder: (sheet) => SheetFrame(
      children: [_StartOrJoin(onDone: () => Navigator.of(sheet).pop())],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final current = state.squad?.id;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in state.squads)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChipPill(
                key: ValueKey('switch-${s.id}'),
                selected: s.id == current,
                color: AppColors.lime,
                onTap: () => state.selectSquad(s.id),
                child: Text(s.name),
              ),
            ),
          if (state.squads.length < 5)
            ChoiceChipPill(
              key: const ValueKey('new-squad'),
              selected: false,
              color: AppColors.lilac,
              onTap: () => _newSquad(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhIcons.plusBold, size: 14),
                  SizedBox(width: 6),
                  Text('New squad'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Everyone you can split with and where you stand with each.
class _FriendsCard extends StatelessWidget {
  const _FriendsCard();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final friends = state.friendPeople;
    final balances = state.friendBalances;
    final owedToYou = balances.values
        .where((v) => v > 0)
        .fold(0, (a, b) => a + b);
    final youOwe = -balances.values
        .where((v) => v < 0)
        .fold(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Friends & balances',
          trailing: _HeaderPill(
            label: 'Split a bill',
            onTap: () => showSplitBillSheet(context, inSquad: null),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (owedToYou > 0 || youOwe > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    [
                      if (owedToYou > 0)
                        'You\'re owed ${money(owedToYou / 100)}',
                      if (youOwe > 0)
                        '${owedToYou > 0 ? 'you' : 'You'} owe '
                            '${money(youOwe / 100)}',
                    ].join(' · '),
                    style: AppText.label,
                  ),
                ),
              if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Add a friend with their code, or start a squad, to split '
                    'bills that show up for both of you.',
                    style: AppText.label,
                  ),
                ),
              for (final f in friends)
                Pressable(
                  key: ValueKey('friend-${f.id}'),
                  onTap: () => showFriendSheet(context, f.id),
                  scale: 0.98,
                  semanticLabel: f.name,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Text(f.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.name,
                            style: AppText.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          switch (balances[f.id] ?? 0) {
                            0 => 'settled',
                            final c when c > 0 => 'owes you ${money(c / 100)}',
                            final c => 'you owe ${money(-c / 100)}',
                          },
                          style: AppText.label.copyWith(
                            color: balanceColor(balances[f.id] ?? 0),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          PhIcons.caretRight,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              Center(
                child: TextButton.icon(
                  onPressed: () => showAddFriendSheet(context),
                  icon: const Icon(PhIcons.plusBold, size: 16),
                  label: const Text('Add friend'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// With "simplify debts" on: who pays whom so the squad is square.
class _FewestPayments extends StatelessWidget {
  const _FewestPayments({required this.squad});
  final Squad squad;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final payments = state.simplifiedPayments(squad);
    if (payments.isEmpty) return const SizedBox.shrink();
    String name(String id) =>
        id == state.me ? 'You' : state.person(id)?.name ?? 'Someone';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('To settle ${squad.name}', style: AppText.heading),
          const SizedBox(height: 4),
          Text(
            'The fewest payments that square everyone up.',
            style: AppText.label,
          ),
          const SizedBox(height: 10),
          for (final p in payments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${name(p.from)} → ${name(p.to)}',
                      style: AppText.body,
                    ),
                  ),
                  Text(
                    money(p.amountCents / 100),
                    style: AppText.number.copyWith(
                      fontSize: 16,
                      color: p.to == state.me
                          ? AppColors.lime
                          : p.from == state.me
                          ? AppColors.red
                          : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Splits extends StatelessWidget {
  const _Splits({required this.splits, this.real = false});
  final List<BillSplit> splits;

  /// Signed in with real friends: these are only the IOUs with people not
  /// on Runway, and they're hidden when there are none.
  final bool real;

  @override
  Widget build(BuildContext context) {
    if (real && splits.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          real ? 'Not on Runway' : 'Roommate splits',
          trailing: real
              ? null
              : _HeaderPill(
                  label: 'Split a bill',
                  onTap: () => showSplitBillSheet(context),
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
