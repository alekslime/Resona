import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/ui/splash_motion.dart';

/// Launch splash, ported from Resonant's SplashScreen: dots fly in and gather,
/// orbit, land one by one in the braille R and pulse, then rings ripple out
/// while the wordmark rises letter by letter. The soundtrack honours Sound
/// cues and a haptic ticks each landing. Then it scales and fades to uncover
/// the UI underneath. With reduce motion it shows the finished mark still,
/// with no sound or buzz, and only a brief fade ends it.
///
/// Drawn in the active theme, on the same flat background Home sits on, so
/// the menu visually continues from the splash.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, required this.onFinished, this.onExitStart});

  /// Called after the exit fade, when Home should take over.
  final VoidCallback onFinished;

  /// Called as the exit fade starts.
  final VoidCallback? onExitStart;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

/// The holds and fades around the choreography, in ms.
abstract final class SplashTiming {
  static const exitMs = 350;

  /// How long the finished logo and wordmark stay before the fade out.
  static const holdMs = 1500;

  static const stillHoldMs = 1500;
  static const stillExitMs = 180;
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _time;
  late final AnimationController _exit;
  final _ticks = <Timer>[];
  bool _started = false;
  bool _reduce = false;
  bool _done = false;

  /// A tap skips the show: judges should never wait. Guards the
  /// natural ending too, so onFinished fires exactly once.
  void _skip() {
    if (_done) return;
    _done = true;
    for (final tick in _ticks) {
      tick.cancel();
    }
    _ticks.clear();
    widget.onFinished();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onFinished();
  }

  @override
  void initState() {
    super.initState();
    _time = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds:
            (SplashMotion.animS / SplashSound.speed * 1000).round(),
      ),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: SplashTiming.exitMs),
    );
  }

  @override
  void dispose() {
    for (final tick in _ticks) {
      tick.cancel();
    }
    _time.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = MediaQuery.of(context).disableAnimations;
    if (_reduce) {
      _time.value = 1;
      _runStill();
    } else {
      _runFull();
    }
  }

  Future<void> _runFull() async {
    unawaited(ref.read(cuesProvider).splash());
    final haptics = ref.read(hapticsProvider);
    for (var i = 0; i < 4; i++) {
      _ticks.add(Timer(Duration(milliseconds: SplashMotion.landingMs(i)), () {
        if (mounted) haptics.play(HapticPattern.confirm);
      }));
    }
    await _time.forward();
    if (!mounted) return;
    await Future<void>.delayed(
        const Duration(milliseconds: SplashTiming.holdMs));
    if (!mounted) return;
    widget.onExitStart?.call();
    await _exit.forward();
    if (!mounted) return;
    _finish();
  }

  Future<void> _runStill() async {
    await Future<void>.delayed(
        const Duration(milliseconds: SplashTiming.stillHoldMs));
    if (!mounted) return;
    widget.onExitStart?.call();
    _exit.duration =
        const Duration(milliseconds: SplashTiming.stillExitMs);
    await _exit.forward();
    if (!mounted) return;
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final size = MediaQuery.sizeOf(context);
    final geo = SplashMotion.geometry(size.width, size.height);
    return AnimatedBuilder(
      animation: Listenable.merge([_time, _exit]),
      builder: (context, _) {
        final t = _time.value * SplashMotion.animS;
        final e = _exit.value;
        final wordDp = (size.width * 0.07).clamp(24.0, 44.0);
        final tagDp = (size.width * 0.036).clamp(14.0, 20.0);
        final top = geo.cy + 490 * geo.scale + 34;
        return GestureDetector(
          onTap: _skip,
          child: Opacity(
            opacity: 1 - e,
            child: Transform.scale(
              scale: _reduce ? 1 : 1 + e * 0.14,
              child: Container(
                color: palette.background,
                child: Stack(
                children: [
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _SplashPainter(
                          t: t,
                          geo: geo,
                          ink: palette.ink,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: Semantics(
                      label: 'Resonant. Learn by listening.',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(left: wordDp * 0.34),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < 8; i++)
                                    _SplashLetter(
                                      letter: 'RESONANT'[i],
                                      t: t,
                                      index: i,
                                      size: wordDp,
                                      ink: palette.ink,
                                      family: font.family,
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SplashTagline(
                              t: t,
                              size: tagDp,
                              ink: palette.ink,
                              family: font.family,
                            ),
                          ],
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
      },
    );
  }
}

class _SplashLetter extends StatelessWidget {
  const _SplashLetter({
    required this.letter,
    required this.t,
    required this.index,
    required this.size,
    required this.ink,
    required this.family,
  });

  final String letter;
  final double t;
  final int index;
  final double size;
  final Color ink;
  final String family;

  @override
  Widget build(BuildContext context) {
    final p =
        ((t - SplashMotion.wordAt - index * 0.045) / 0.6).clamp(0.0, 1.0);
    return Opacity(
      opacity: math.min(1, p * 1.2),
      child: Transform.translate(
        offset: Offset(0, (1 - SplashMotion.easeOut(p)) * 0.6 * size),
        child: Text(
          letter,
          style: TextStyle(
            fontFamily: family,
            fontWeight: FontWeight.w900,
            fontSize: size,
            letterSpacing: 0.34 * size,
            color: ink,
          ),
        ),
      ),
    );
  }
}

class _SplashTagline extends StatelessWidget {
  const _SplashTagline({
    required this.t,
    required this.size,
    required this.ink,
    required this.family,
  });

  final double t;
  final double size;
  final Color ink;
  final String family;

  @override
  Widget build(BuildContext context) {
    final alpha =
        ((t - SplashMotion.wordAt - 0.55) / 0.8).clamp(0.0, 1.0) * 0.85;
    return Opacity(
      opacity: alpha,
      child: Text(
        'Learn by listening.',
        style: TextStyle(
          fontFamily: family,
          fontWeight: FontWeight.w600,
          fontSize: size,
          letterSpacing: 0.06 * size,
          color: ink,
        ),
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  _SplashPainter({required this.t, required this.geo, required this.ink});

  final double t;
  final SplashGeometry geo;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    for (var j = 0; j < SplashMotion.ringCount; j++) {
      final p = SplashMotion.ringProgress(j, t);
      if (p < 0) continue;
      canvas.drawCircle(
        Offset(geo.cx, geo.cy),
        (170 + p * 800) * geo.scale,
        Paint()
          ..color = ink.withValues(alpha: 0.4 * math.pow(1 - p, 1.5))
          ..style = PaintingStyle.stroke
          ..strokeWidth = (10 * (1 - p) + 2) * geo.scale,
      );
    }
    for (var i = 0; i < 4; i++) {
      final pose = SplashMotion.dotPose(i, t, size.width, size.height, geo);
      canvas.drawCircle(
        Offset(pose.x, pose.y),
        pose.radius,
        Paint()..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) =>
      old.t != t || old.ink != ink || old.geo != geo;
}
