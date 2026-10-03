import 'package:flutter/material.dart';

import '../widgets/aurora_background.dart';
import '../widgets/mochi_takeoff.dart';
import '../widgets/transitions.dart';
import 'shell.dart';

/// Launch screen for someone who's already signed in: "Mochi's Takeoff",
/// then Home opens through a circle that grows out of Mochi.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({super.key});

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro> {
  bool _leaving = false;

  void _openHome(Offset from, {bool instant = false}) {
    if (_leaving) return;
    _leaving = true;
    Navigator.of(context).pushReplacement(
      instant
          ? FadeScaleRoute<void>(builder: (_) => const Shell())
          : CircularRevealRoute<void>(
              center: from,
              builder: (_) => const Shell(),
            ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openHome(Offset.zero, instant: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: MochiTakeoff(
          logoBaseline: (size) => Offset(size.width / 2, size.height * 0.4),
          onLanded: _openHome,
          onFinished: () {},
        ),
      ),
    );
  }
}
