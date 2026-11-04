import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/readiness.dart';
import '../game/animal_roster.dart';

/// Small code-driven idle/victory motion of authored art; no skeletal frames.
class PilotPose extends StatefulWidget {
  const PilotPose(
    this.pilot, {
    this.height = 120,
    this.victory = false,
    super.key,
  });
  final AnimalPilot pilot;
  final double height;
  final bool victory;
  @override
  State<PilotPose> createState() => _PilotPoseState();
}

class _PilotPoseState extends State<PilotPose>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        AppServices.of(context).preferences.reduceMotion) {
      _motion.stop();
      _motion.value = 0;
    } else if (!_motion.isAnimating) {
      _motion.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PilotPose old) {
    super.didUpdateWidget(old);
    if (old.pilot.id != widget.pilot.id) {
      _motion.value = 0;
      if (!MediaQuery.disableAnimationsOf(context) &&
          !AppServices.of(context).preferences.reduceMotion) {
        _motion.forward();
      }
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = animalPilots.indexOf(widget.pilot),
        factor = widget.victory ? 1.6 : 1.0;
    return AnimatedBuilder(
      animation: _motion,
      child: Image.asset(
        widget.pilot.portrait,
        height: widget.height,
        cacheWidth: 256,
        fit: BoxFit.contain,
        errorBuilder: (_, e, s) => const Text('캐릭터 이미지 준비 오류'),
      ),
      builder: (context, child) {
        final wave = math.sin(_motion.value * math.pi * 2);
        final hop = [4.0, 2, 1.5, 1, 3, 2, 5, 1.5, 2.5, 4, 4, 1.5][index];
        final angle =
            [
              .01,
              .035,
              .01,
              .012,
              .035,
              .025,
              .04,
              .045,
              .035,
              .015,
              .02,
              .035,
            ][index] *
            wave *
            factor;
        return Transform.translate(
          offset: Offset(index == 8 ? wave * 3 : 0, -wave.abs() * hop * factor),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
    );
  }
}
