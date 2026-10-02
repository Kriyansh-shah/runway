import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/glass.dart';
import '../widgets/pressable.dart';
import 'coach_screen.dart';
import 'home_screen.dart';
import 'quick_add_sheet.dart';
import 'squad_screen.dart';

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

  void _select(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  void _openQuickAdd() => showQuickAddSheet(context);

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

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        height: navBarHeight,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.blur_circular_rounded,
              label: 'Home',
              active: current == 0,
              onTap: () => onSelect(0),
            ),
            _NavItem(
              icon: Icons.auto_awesome_rounded,
              label: 'Coach',
              active: current == 1,
              onTap: () => onSelect(1),
            ),
            Expanded(
              child: Center(child: _AddButton(onTap: onAdd)),
            ),
            _NavItem(
              icon: Icons.groups_rounded,
              label: 'Squad',
              active: current == 2,
              onTap: () => onSelect(2),
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
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.text : AppColors.muted;
    return Expanded(
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: Motion.fast,
              child: active
                  ? ShaderMask(
                      key: const ValueKey(true),
                      blendMode: BlendMode.srcIn,
                      shaderCallback: AppGradients.brand.createShader,
                      child: Icon(icon, size: 26),
                    )
                  : Icon(
                      icon,
                      key: const ValueKey(false),
                      size: 26,
                      color: color,
                    ),
            ),
            const SizedBox(height: 4),
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
      scale: 0.9,
      semanticLabel: 'Add expense',
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.brand,
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: 0.6),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}
