import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/menu_focus.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/speech.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/celebration.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/key_shortcuts.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../../learn/domain/lesson_data.dart';
import '../../learn/domain/milestones.dart';
import '../../learn/domain/profile_motion.dart';
import '../../learn/domain/progress.dart';
import '../../learn/domain/quiz_data.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'name_setup_screen.dart';

/// One line on the screen. [action] is what a tap does; null means
/// the line is only read.
class _ProfileRow {
  const _ProfileRow(this.label, {this.counts = false, this.action});

  final String label;
  final bool counts;
  final VoidCallback? action;
}

/// Your progress, ported from Resonant's ProfileScreen: the name in
/// braille dots, then the streak and counts climbing once, the
/// milestones, and the theme, font and speed rows that change in
/// place. New milestones are celebrated once, after the count-up.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late MenuFocus _focus;
  final _scroll = ScrollController();
  late List<GlobalKey> _keys;
  late final AnimationController _count;
  int _rowCount = 0;
  bool _celebrationArmed = false;
  Timer? _celebration;
  bool _cheering = false;

  @override
  void initState() {
    super.initState();
    _count = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _focus = MenuFocus(count: 1);
    _keys = [GlobalKey()];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _count.value = 1;
    } else if (!_count.isAnimating && _count.value < 1) {
      unawaited(_count.forward());
    }
    // Celebrated once, after the numbers have counted up. Marked as
    // told afterwards, so leaving early does not lose the celebration.
    if (_celebrationArmed) return;
    _celebrationArmed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fresh = _fresh();
      if (fresh.isEmpty) return;
      _celebration =
          Timer(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        _buzz(HapticPattern.correct);
        _speak(milestoneAnnouncement(fresh, name: _name));
        setState(() => _cheering = true);
        ref
            .read(milestoneSeenProvider.notifier)
            .markSeen(fresh.map((m) => m.id));
      });
    });
  }

  @override
  void dispose() {
    _celebration?.cancel();
    _scroll.dispose();
    _count.dispose();
    super.dispose();
  }

  String? get _name {
    final name = ref.read(userNameProvider);
    if (name == null || name.trim().isEmpty) return null;
    return name.trim();
  }

  ProfileStats _stats() => ProfileSummary.stats(
        progress: ref.read(quizBookProvider),
        quizIds: [for (final q in allQuizSets) q.id],
        materials: 0,
        activity: ref.read(activityProvider),
        today: ref.read(activityProvider.notifier).today,
        lessonIds: [for (final l in builtInLessons) l.id],
      );

  List<Milestone> _reached(ProfileStats stats) =>
      reachedMilestones(stats, ref.read(milestoneSeenProvider));

  List<Milestone> _fresh() {
    final stats = _stats();
    return freshMilestones(stats, ref.read(milestoneSeenProvider));
  }

  List<_ProfileRow> _rows() {
    final stats = _stats();
    final name = _name;
    final reached = _reached(stats);
    final fresh = _fresh();
    return [
      _ProfileRow('Your name: ${name ?? 'not set'}',
          action: _openName),
      _ProfileRow('How am I doing?', action: () {
        _speak(ProfileSummary.spoken(name, stats));
      }),
      _ProfileRow(ActivityText.streakLine(stats.streak), counts: true),
      _ProfileRow(
          ActivityText.weeklyLine(ref.read(activityProvider).activeDays,
              ref.read(activityProvider.notifier).today),
          counts: true),
      if (stats.longestStreak > stats.streak)
        _ProfileRow(ActivityText.longestLine(stats.longestStreak),
            counts: true),
      if (stats.lessonsTotal > 0)
        _ProfileRow(ProfileSummary.lessonsLine(stats), counts: true),
      _ProfileRow(ProfileSummary.quizLine(stats), counts: true),
      if (ProfileSummary.averageLine(stats) != null)
        _ProfileRow(ProfileSummary.averageLine(stats)!, counts: true),
      _ProfileRow(ProfileSummary.materialsLine(stats), counts: true),
      _ProfileRow(milestoneRowLine(reached, fresh), action: () {
        _speak(milestoneSpoken(reached));
      }),
      _ProfileRow(
          ActivityText.listeningLine(stats.listeningSeconds)),
      _ProfileRow('Color theme: ${ref.read(paletteProvider).label}',
          action: _nextTheme),
      _ProfileRow('Font: ${ref.read(fontProvider).label}',
          action: _nextFont),
      _ProfileRow(
          'Speech speed: ${speechSpeedLabel(ref.read(speechProvider).rate)}',
          action: _speedHelp),
    ];
  }

  void _syncFocus(int count) {
    if (count == _rowCount) return;
    _rowCount = count;
    final at = _focus.index.clamp(0, count - 1);
    _focus = MenuFocus(count: count)..jumpTo(at);
    _keys = [for (var i = 0; i < count; i++) GlobalKey()];
  }

  /// A tap the rows took themselves: the surface drops its echo.
  bool _onRow(Offset position) => _keys.any((k) {
        final box = k.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) return false;
        return Rect.fromPoints(
          box.localToGlobal(Offset.zero),
          box.localToGlobal(box.size.bottomRight(Offset.zero)),
        ).contains(position);
      });

  void _speak(String text) => ref.read(speechProvider).speak(text);

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _openName() {
    Navigator.of(context).push(resonantRoute(
      const NameSetupScreen(),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  void _nextTheme() {
    ref.read(paletteProvider.notifier).next();
    _buzz(HapticPattern.confirm);
    setState(() {});
  }

  void _nextFont() {
    ref.read(fontProvider.notifier).next();
    _buzz(HapticPattern.confirm);
    setState(() {});
  }

  void _speedHelp() {
    _speak(
        'Hold the right edge, then drag up to speak faster or down to slow down.');
  }

  void _move(int delta, List<_ProfileRow> rows) {
    final moved = delta > 0 ? _focus.next() : _focus.previous();
    if (!moved) return;
    setState(() {});
    final target = _keys[_focus.index].currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(
        target,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 250),
      ));
    }
    _speak(rows[_focus.index].label);
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _jumpTo(int i, List<_ProfileRow> rows) {
    _focus.jumpTo(i);
    setState(() {});
    _speak(rows[i].label);
    if (rows[i].action != null) {
      rows[i].action!();
    } else {
      _buzz(HapticPattern.select);
    }
  }

  void _activate(List<_ProfileRow> rows) {
    final row = rows[_focus.index];
    _buzz(HapticPattern.select);
    if (row.action != null) {
      row.action!();
    } else {
      _speak(row.label);
    }
  }

  void _repeat(List<_ProfileRow> rows) => _speak(rows[_focus.index].label);

  void _back() {
    _buzz(HapticPattern.back);
    _speak('Back to Home.');
    unawaited(goBack(context, home: const HomeScreen()));
  }

  void _whereAmI(List<_ProfileRow> rows) {
    _speak(
        'Profile. Currently focused: ${rows.isEmpty ? 'loading' : rows[_focus.index].label}.');
  }

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
    setState(() {});
  }

  void _onGesture(Gesture gesture, List<_ProfileRow> rows) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        _move(1, rows);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        _move(-1, rows);
      case Tap(zone: Zone.center):
        _activate(rows);
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _repeat(rows);
      case LongPress(zone: Zone.rightEdge):
        _back();
      case ThreeFingerTap():
        _repeat(rows);
      case ThreeFingerHold():
        _whereAmI(rows);
      case HoldSpeedUp():
        _speed(0.1);
        _buzz(HapticPattern.speedUp);
      case HoldSpeedDown():
        _speed(-0.1);
        _buzz(HapticPattern.speedDown);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(paletteProvider);
    ref.watch(quizBookProvider);
    ref.watch(activityProvider);
    ref.watch(milestoneSeenProvider);
    final name = ref.watch(userNameProvider);
    final rows = _rows();
    _syncFocus(rows.length);
    return Stack(
      children: [
        ResonantScaffold(
          title: 'Profile',
          subtitle: name ?? 'Your progress',
          onBack: () => unawaited(goBack(context, home: const HomeScreen())),
          backAnnouncement: 'Back to Home.',
      child: ListShortcuts(
        onMove: (d) => _move(d, rows),
        onActivate: () => _activate(rows),
        onBack: _back,
        child: GestureSurface(
          exploreEnabled: false,
          twoFingerSwipe: true,
          ignoreChildGestureAt: _onRow,
          onGesture: (g) => _onGesture(g, rows),
          child: SingleChildScrollView(
            controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              _Avatar(name: name),
              const SizedBox(height: 16),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _ProfileRowCard(
                  key: _keys[i],
                  label: rows[i].label,
                  counts: rows[i].counts,
                  focused: i == _focus.index,
                  index: i,
                  progress: _count,
                  onTap: () => _jumpTo(i, rows),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
        ),
        ),
        if (_cheering)
          CelebrationOverlay(
            color: ref.watch(paletteProvider).ink,
            onDone: () {
              if (mounted) setState(() => _cheering = false);
            },
          ),
      ],
    );
  }
}

/// One profile line: the label in a card, the focused one inverted.
/// Count lines climb from zero once, when they first arrive.
class _ProfileRowCard extends ConsumerWidget {
  const _ProfileRowCard({
    super.key,
    required this.label,
    required this.counts,
    required this.focused,
    required this.index,
    required this.progress,
    required this.onTap,
  });

  final String label;
  final bool counts;
  final bool focused;
  final int index;
  final Animation<double> progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return Semantics(
      label: focused ? '$label, focused' : label,
      child: EnterStagger(
        index: index,
        child: FocusLift(
          focused: focused,
          themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
          child: GestureDetector(
            onTap: onTap,
            child: FocusColor(
              target: focused ? palette.ink : palette.card,
              builder: (context, card) => Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: cardShape(palette),
                  border: cardBorder(palette),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 22),
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (context, _) => Text(
                    counts
                        ? CountUp.apply(label, progress.value)
                        : label,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      height: 32 / 26,
                      color: focused ? palette.onInk : palette.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The person's name in braille, one cell per letter, so it is unique
/// without a photo. The cells appear one after another (all at once
/// with Reduce motion on). With no name yet, the Resonant mark
/// stands in.
class _Avatar extends ConsumerStatefulWidget {
  const _Avatar({required this.name});

  final String? name;

  @override
  ConsumerState<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends ConsumerState<_Avatar>
    with TickerProviderStateMixin {
  int _shown = 0;
  Timer? _timer;
  Timer? _sweepWait;
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AvatarMotion.sweepMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cells = BrailleAvatar.cells(widget.name);
    if (MediaQuery.of(context).disableAnimations || cells.isEmpty) {
      _shown = cells.length;
      return;
    }
    _timer?.cancel();
    _sweepWait?.cancel();
    _shown = 0;
    _timer = Timer.periodic(
        const Duration(milliseconds: AvatarMotion.cellGapMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_shown < cells.length) {
        setState(() => _shown++);
        return;
      }
      timer.cancel();
      // The light is spent at 1; shine() keeps a faint tail on the
      // last cell, so it is cut there.
      _sweepWait = Timer(const Duration(milliseconds: AvatarMotion.cellMs),
          () {
        if (mounted) _sweep.forward(from: 0);
      });
    });
  }

  @override
  void didUpdateWidget(_Avatar old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) {
      _sweep.value = 0;
      didChangeDependencies();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweepWait?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = ref.watch(paletteProvider).ink;
    final cells = BrailleAvatar.cells(widget.name);
    if (cells.isEmpty) {
      return SizedBox(
        width: 140,
        height: 140,
        child: ResonantDots(
            state: DotsState.idle, size: 140, color: ink),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        final cellW = BrailleAvatar.cellWidth(
            count: cells.length, available: box.maxWidth);
        return Semantics(
          label: 'Your name in braille dots',
          child: AnimatedBuilder(
            animation: _sweep,
            builder: (context, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < cells.length; i++) ...[
                  if (i > 0) SizedBox(width: cellW * (16 / 44)),
                  _BrailleCell(
                    raised: cells[i],
                    progress: i < _shown ? 1 : 0,
                    width: cellW,
                    shine: _sweep.value >= 1
                        ? 0
                        : AvatarMotion.shine(
                            _sweep.value, i, cells.length),
                    ink: ink,
                    animate:
                        !MediaQuery.of(context).disableAnimations,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One braille cell: the raised dots light one after another and swell
/// a little as they arrive; the rest just fade in.
class _BrailleCell extends StatefulWidget {
  const _BrailleCell({
    required this.raised,
    required this.progress,
    required this.width,
    required this.shine,
    required this.ink,
    required this.animate,
  });

  final List<int> raised;
  final double progress;
  final double width;
  final double shine;
  final Color ink;
  final bool animate;

  @override
  State<_BrailleCell> createState() => _BrailleCellState();
}

class _BrailleCellState extends State<_BrailleCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AvatarMotion.cellMs),
    );
    if (widget.progress >= 1) {
      if (widget.animate) {
        unawaited(_controller.forward());
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void didUpdateWidget(_BrailleCell old) {
    super.didUpdateWidget(old);
    if (widget.progress >= 1 && _controller.value < 1) {
      if (widget.animate) {
        unawaited(_controller.forward());
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.width * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _CellPainter(
            raised: widget.raised,
            progress: _controller.value,
            shine: widget.shine,
            ink: widget.ink,
          ),
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter({
    required this.raised,
    required this.progress,
    required this.shine,
    required this.ink,
  });

  final List<int> raised;
  final double progress;
  final double shine;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.17;
    final colX = [size.width * 0.25, size.width * 0.75];
    final rowY = [size.height * 0.15, size.height * 0.5, size.height * 0.85];
    for (var dot = 1; dot <= 6; dot++) {
      final col = dot <= 3 ? 0 : 1;
      final row = (dot - 1) % 3;
      final on = raised.contains(dot);
      final local = AvatarMotion.dotProgress(progress, dot);
      final paint = Paint()
        ..color = ink.withValues(
            alpha: on
                ? local
                : AvatarMotion.restingAlpha(progress) + 0.45 * shine)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(colX[col], rowY[row]),
        (on ? r * AvatarMotion.swell(local) : r) * (1 + 0.18 * shine),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.raised != raised ||
      old.progress != progress ||
      old.shine != shine ||
      old.ink != ink;
}
