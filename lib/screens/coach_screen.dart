import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/coach.dart';
import '../app/format.dart';
import '../app/theme.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import '../widgets/pressable.dart';
import 'shell.dart';
import '../widgets/ph_icons.dart';
import 'jar_sheets.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

sealed class _Message {
  _Message() : id = _nextId++;
  static int _nextId = 0;
  final int id;
}

class _UserMessage extends _Message {
  _UserMessage(this.text);
  final String text;
}

class _CoachMessage extends _Message {
  _CoachMessage(this.reply);
  final CoachReply reply;
}

class _CoachScreenState extends State<CoachScreen> {
  static const _chips = [
    'Boba \$6',
    'Dinner out \$25',
    'Concert ticket \$60',
    'AirPods \$129',
    'Spring break trip \$600',
  ];

  /// Minimum "thinking" time so the typing indicator reads as intentional.
  static const _typingDelay = Duration(milliseconds: 900);

  final _messages = <_Message>[
    _CoachMessage(
      const CoachReply.text(
        'Hey! Thinking about buying something? Tell me what it costs and '
        'I\'ll check it against your runway. 💸',
      ),
    ),
  ];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _typing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String text) async {
    final q = text.trim();
    if (q.isEmpty || _typing) return;
    HapticFeedback.lightImpact();
    _input.clear();
    final state = AppScope.read(context);
    setState(() {
      _messages.add(_UserMessage(q));
      _typing = true;
    });
    _scrollToEnd();
    final (reply, _) = await (
      state.coach.ask(q, state.grounding),
      Future<void>.delayed(_typingDelay),
    ).wait;
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _typing = false;
      _messages.add(_CoachMessage(reply));
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.slow,
        curve: Motion.out,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).snapshot;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = math.max(navClearance(context) - 16, keyboard + 12);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Entrance(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const GradientText(
                          'Can I afford it?',
                          style: AppText.title,
                        ),
                        const SizedBox(height: 2),
                        Text('Your money coach', style: AppText.label),
                      ],
                    ),
                  ),
                  Pill(
                    label: 'Safe today ${money(s.safeToSpendToday)}',
                    color: s.safeToSpendToday >= 0
                        ? AppColors.lime
                        : AppColors.red,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ShaderMask(
              // Fade messages out at the top edge.
              shaderCallback: (r) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white],
                stops: [0, 0.05],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: _messages.length + (_typing ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return const Entrance(
                      key: ValueKey('typing'),
                      index: 0,
                      child: _TypingBubble(),
                    );
                  }
                  final m = _messages[i];
                  return Entrance(
                    key: ValueKey(m.id),
                    index: i == 0 ? 1 : 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: switch (m) {
                        _UserMessage(:final text) => _UserBubble(text),
                        _CoachMessage(:final reply) =>
                          reply.assessment != null
                              ? _VerdictCard(reply.assessment!)
                              : _CoachBubble(reply.text!),
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          Entrance(
            index: 2,
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _chips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Center(
                  child: Pressable(
                    onTap: () => _ask(_chips[i]),
                    haptic: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.lilac.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _chips[i],
                        style: AppText.body.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedPadding(
            duration: Motion.fast,
            curve: Motion.out,
            padding: EdgeInsets.fromLTRB(16, 10, 16, bottom),
            child: Entrance(
              index: 3,
              child: _InputBar(controller: _input, onSend: _ask, busy: _typing),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.busy,
  });
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSend,
              textInputAction: TextInputAction.send,
              style: AppText.body,
              decoration: InputDecoration(
                hintText: 'Can I afford… e.g. "Shoes \$80"',
                hintStyle: AppText.body.copyWith(color: AppColors.muted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Pressable(
            onTap: busy ? null : () => onSend(controller.text),
            semanticLabel: 'Send',
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.brand,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.lime.withValues(alpha: 0.3),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(PhIcons.arrowUpBold, color: AppColors.onLime),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: AppGradients.brand,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.18),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          text,
          style: AppText.body.copyWith(
            color: AppColors.onLime,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(text, style: AppText.body),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Semantics(
            label: 'Coach is typing',
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Transform.translate(
                      offset: Offset(
                        0,
                        -4 *
                            math.max(
                              0,
                              math.sin(
                                (_controller.value - i * 0.15) * 2 * math.pi,
                              ),
                            ),
                      ),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  const _VerdictCard(this.a);
  final Assessment a;

  (Color, String) get _style => switch (a.verdict) {
    Verdict.yes => (AppColors.lime, '✅'),
    Verdict.trade => (AppColors.butter, '🔁'),
    Verdict.no => (AppColors.red, '⏳'),
  };

  @override
  Widget build(BuildContext context) {
    final (color, emoji) = _style;
    final days = a.runwayDaysLost;
    final daysText = days == 0
        ? 'no change'
        : days < 1
        ? '< 1 day'
        : '−${plural(days.round(), 'day')}';
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 30),
            ],
          ),
          child: GlassCard(
            strong: true,
            borderColor: color.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.headline,
                        style: AppText.heading.copyWith(
                          color: color,
                          fontSize: 19,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${a.item[0].toUpperCase()}${a.item.substring(1)} · ${money(a.amount)}',
                  style: AppText.label,
                ),
                const SizedBox(height: 10),
                Text(a.message, style: AppText.body),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DAILY', style: AppText.caption),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  money(a.dailyBefore),
                                  style: AppText.number.copyWith(
                                    fontSize: 16,
                                    color: AppColors.muted,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(
                                    PhIcons.arrowRightBold,
                                    size: 14,
                                    color: AppColors.muted,
                                  ),
                                ),
                                Flexible(
                                  child: RollingNumber(
                                    value: a.dailyAfter,
                                    style: AppText.number.copyWith(
                                      fontSize: 16,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('RUNWAY', style: AppText.caption),
                          const SizedBox(height: 4),
                          Text(
                            daysText,
                            style: AppText.number.copyWith(
                              fontSize: 16,
                              color: days == 0 ? AppColors.lime : color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (a.verdict == Verdict.no && a.plan != null) ...[
                  const SizedBox(height: 12),
                  _SaveForIt(a),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Save for it" on a not-now answer: starts a savings goal named after
/// what was asked about. Once there is one, it points to the Savings tab.
class _SaveForIt extends StatelessWidget {
  const _SaveForIt(this.a);
  final Assessment a;

  String get _name => a.item == 'that' ? '' : a.item;

  Future<void> _start(BuildContext context) async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final jar = await showNewJarSheet(context, name: _name, price: a.amount);
    if (jar == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Saving for ${jar.name}. Put money in from Savings.'),
        action: SnackBarAction(
          label: 'See it',
          onPressed: () => state.requestedTab.value = 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final name = _name.toLowerCase();
    final saving =
        name.isNotEmpty && state.jars.any((j) => j.name.toLowerCase() == name);
    return Pressable(
      onTap: saving
          ? () => state.requestedTab.value = 1
          : () => _start(context),
      semanticLabel: saving ? 'See it in Savings' : 'Save for it',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lime.withValues(alpha: 0.5)),
          color: AppColors.lime.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              saving ? PhIcons.checkBold : PhIcons.piggyBank,
              size: 18,
              color: AppColors.lime,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                saving ? 'Saving for it · See it' : 'Save for it',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(
                  color: AppColors.lime,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
