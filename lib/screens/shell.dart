import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../app/purchase_link.dart';
import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/celebrations.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import 'coach_screen.dart';
import 'home_screen.dart';
import 'quick_add_sheet.dart';
import 'recap_sheet.dart';
import 'squad_screen.dart';
import '../widgets/ph_icons.dart';

/// Height of the floating nav bar (excluding the safe-area inset).
const navBarHeight = 68.0;

/// Bottom padding scrollable screens need so content clears the nav bar.
double navClearance(BuildContext context) =>
    navBarHeight + MediaQuery.paddingOf(context).bottom + 28;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;
  final _visited = <int>{0};

  static const _screens = [HomeScreen(), CoachScreen(), SquadScreen()];

  late final ValueNotifier<ApplePayPurchase?> _purchases;
  late final ValueNotifier<Recap?> _recaps;

  @override
  void initState() {
    super.initState();
    // A purchase or recap may have arrived during login, setup or the
    // intro; open it once Home is on screen, and any later ones as they
    // come in.
    final state = AppScope.read(context);
    _purchases = state.pendingPurchase..addListener(_openPurchase);
    _recaps = state.pendingRecap..addListener(_openRecap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPurchase();
      _openRecap();
    });
  }

  @override
  void dispose() {
    _purchases.removeListener(_openPurchase);
    _recaps.removeListener(_openRecap);
    super.dispose();
  }

  void _openRecap() {
    final recap = _recaps.value;
    if (recap == null || !mounted) return;
    _recaps.value = null;
    _select(0, haptic: false);
    AppScope.read(context).recapShown(recap.ended);
    showRecapSheet(context, recap);
  }

  void _openPurchase() {
    final purchase = _purchases.value;
    if (purchase == null || !mounted) return;
    _purchases.value = null;
    _openQuickAdd(purchase: purchase);
  }

  void _select(int tab, {bool haptic = true}) {
    if (tab == _tab) return;
    if (haptic) HapticFeedback.selectionClick();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  /// After logging: jump to Home and toss a coin from the Log button into
  /// the ring.
  Future<void> _openQuickAdd({ApplePayPurchase? purchase}) async {
    final from = await showQuickAddSheet(context, purchase: purchase);
    if (from == null || !mounted) return;
    _select(0, haptic: false);
    await Future<void>.delayed(Motion.fast);
    if (mounted) flyCoinToRing(context, from: from);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AuroraBackground(
        child: Stack(
          children: [
            // Every visited tab stays mounted, so scroll positions and chat
            // history survive switching. Inactive tabs stop ticking.
            for (var i = 0; i < _screens.length; i++)
              _TabLayer(
                active: i == _tab,
                direction: i < _tab ? -1 : 1,
                child: _visited.contains(i)
                    ? _screens[i]
                    : const SizedBox.shrink(),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 10,
              child: _NavBar(
                current: _tab,
                onSelect: _select,
                onAdd: _openQuickAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLayer extends StatelessWidget {
  const _TabLayer({
    required this.active,
    required this.direction,
    required this.child,
  });

  final bool active;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !active,
        // The fade/slide must live *outside* TickerMode: a disabled ticker
        // would freeze the fade-out and leave the old tab visible.
        child: AnimatedSlide(
          offset: active ? Offset.zero : Offset(0.04 * direction, 0),
          duration: Motion.med,
          curve: Motion.out,
          child: AnimatedOpacity(
            opacity: active ? 1 : 0,
            duration: Motion.med,
            curve: Motion.out,
            // Inactive tabs stop their own ambient animations (pet, etc.).
            child: TickerMode(enabled: active, child: child),
          ),
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  /// Nav slots left to right: Home, Coach, (+), Squad.
  static const _slotOfTab = [0, 1, 3];

  @override
  Widget build(BuildContext context) {
    final slot = _slotOfTab[current];
    return FrostedGlass(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: navBarHeight,
        child: Stack(
          children: [
            // Soft lime pill that glides to the selected tab.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: AnimatedAlign(
                  alignment: Alignment(-1 + 2 * slot / 3, 0),
                  duration: Motion.med,
                  curve: Motion.spring,
                  child: FractionallySizedBox(
                    widthFactor: 0.25,
                    heightFactor: 1,
                    child: Center(
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          color: AppColors.lime.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.lime.withValues(alpha: 0.28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lime.withValues(alpha: 0.12),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                _NavItem(
                  icon: PhIcons.house,
                  activeIcon: PhIcons.houseFill,
                  label: 'Home',
                  active: current == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  icon: PhIcons.sparkle,
                  activeIcon: PhIcons.sparkleFill,
                  label: 'Coach',
                  active: current == 1,
                  onTap: () => onSelect(1),
                ),
                Expanded(
                  child: Center(child: _AddButton(onTap: onAdd)),
                ),
                _NavItem(
                  icon: PhIcons.usersThree,
                  activeIcon: PhIcons.usersThreeFill,
                  label: 'Squad',
                  active: current == 2,
                  onTap: () => onSelect(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.lime : AppColors.muted;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Outline → filled morph with a little pop.
            AnimatedSwitcher(
              duration: Motion.med,
              switchInCurve: Motion.spring,
              switchOutCurve: Motion.out,
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.6, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                size: 25,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: Motion.fast,
              style: AppText.caption.copyWith(
                color: color,
                letterSpacing: 0,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      semanticLabel: 'Add expense',
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.brand,
          boxShadow: [
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(PhIcons.plusBold, color: AppColors.onLime, size: 26),
      ),
    );
  }
}
