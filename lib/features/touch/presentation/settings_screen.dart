import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/menu_focus.dart';
import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/speech.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/palettes.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/theme/text_scale.dart';
import '../../../core/theme/text_spacings.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/focus_fade.dart';
import '../../../core/ui/key_shortcuts.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../application/option_picker.dart';
import '../gestures/gesture_phrases.dart';
import '../gestures/gesture_types.dart';
import 'gesture_guide.dart';
import 'gesture_surface.dart';
import 'home_screen.dart';
import 'name_setup_screen.dart';
import 'tour_screen.dart';

/// A preview in progress: [item] is the row, [start] what was in use
/// when it opened (so cancelling can put it back), [index] what shows.
class _Pick {
  const _Pick(this.item, this.start, this.index);

  final String item;
  final int start;
  final int index;

  _Pick moved(int to) => _Pick(item, start, to);
}

/// Settings, ported from Resonant's SettingsScreen: a two-finger list
/// with the focused row inverted. A tap steps the row and speaks the
/// new value; a hold on a theme, font, size or spacing row previews
/// each option on screen before keeping one.
///
/// Only the rows this app can honour yet. The old screen's material
/// import, voice engine, live voice rows, model downloads and debug
/// row belong to systems that have not been ported; the speech-rate
/// row is this app's own, driving the same rate the edge drag
/// adjusts freely.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _items = [
    'Replay Tutorial',
    'Replay guides',
    'Your name',
    'Sound cues',
    'Color theme',
    'Font',
    'Text size',
    'Text spacing',
    'Reduce motion',
    'Speech rate',
    'Clear chat history',
  ];

  /// Rows you can hold and swipe through, with the screen showing
  /// each option as a preview.
  static const _previewable = [
    'Color theme',
    'Font',
    'Text size',
    'Text spacing',
  ];

  late final MenuFocus _focus;
  final _scroll = ScrollController();
  final _guideKey = GlobalKey();
  late final List<GlobalKey> _keys;
  _Pick? _picking;
  bool _awaitingClearConfirm = false;

  @override
  void initState() {
    super.initState();
    _focus = MenuFocus(count: _items.length);
    _keys = [for (var i = 0; i < _items.length; i++) GlobalKey()];
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _label(String item) {
    switch (item) {
      case 'Sound cues':
        return 'Sound cues: ${ref.read(soundCuesProvider) ? 'on' : 'off'}';
      case 'Color theme':
        return 'Color theme: ${ref.read(paletteProvider).label}';
      case 'Font':
        return 'Font: ${ref.read(fontProvider).label}';
      case 'Text size':
        return 'Text size: ${TextScale.percent(ref.read(textScaleProvider))} percent';
      case 'Text spacing':
        return 'Text spacing: ${ref.read(textSpacingProvider).label}';
      case 'Reduce motion':
        return 'Reduce motion: ${ref.read(reduceMotionProvider) ? 'on' : 'off'}';
      case 'Speech rate':
        final rate = ref.read(speechRateProvider);
        return 'Speech rate: ${(rate * 100).round()} percent';
      default:
        return item;
    }
  }

  /// A tap the rows took themselves: the surface drops its echo.
  bool _onRow(Offset position) =>
      guideContains(_guideKey, position) || _keys.any((k) {
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

  void _step(String label, String value) {
    _buzz(HapticPattern.confirm);
    _speak('$label: $value.');
  }

  /// One place for "the user chose this item", shared by the tap
  /// gesture and the on-screen touch target, so the two can never
  /// disagree.
  void _activate(String item) {
    switch (item) {
      case 'Replay Tutorial':
        _awaitingClearConfirm = false;
        Navigator.of(context).push(resonantRoute(
          const TourScreen(),
          reduce: MediaQuery.of(context).disableAnimations,
        ));
      case 'Replay guides':
        _awaitingClearConfirm = false;
        unawaited(resetGuideSeen(ref.read(sharedPreferencesProvider)));
        _buzz(HapticPattern.confirm);
        _speak('Guides will show again on each screen.');
      case 'Your name':
        _awaitingClearConfirm = false;
        Navigator.of(context).push(resonantRoute(
          const NameSetupScreen(),
          reduce: MediaQuery.of(context).disableAnimations,
        ));
      case 'Sound cues':
        _awaitingClearConfirm = false;
        final now = ref.read(soundCuesProvider.notifier).toggle();
        ref.read(cuesProvider).enabled = now;
        // Re-speaking the row speaks the new state ("Sound cues: off").
        // Turning them on sounds one too, so the change is heard.
        _step('Sound cues', now ? 'on' : 'off');
      case 'Color theme':
        _awaitingClearConfirm = false;
        final next = ref.read(paletteProvider.notifier).next();
        setState(() {});
        _step('Color theme', next.label);
      case 'Font':
        _awaitingClearConfirm = false;
        final next = ref.read(fontProvider.notifier).next();
        setState(() {});
        _step('Font', next.label);
      case 'Text size':
        _awaitingClearConfirm = false;
        final next = ref.read(textScaleProvider.notifier).next();
        setState(() {});
        _step('Text size', '${TextScale.percent(next)} percent');
      case 'Text spacing':
        _awaitingClearConfirm = false;
        final next = ref.read(textSpacingProvider.notifier).next();
        setState(() {});
        _step('Text spacing', next.label);
      case 'Reduce motion':
        _awaitingClearConfirm = false;
        final now = ref.read(reduceMotionProvider.notifier).toggle();
        setState(() {});
        _step('Reduce motion', now ? 'on' : 'off');
      case 'Speech rate':
        _awaitingClearConfirm = false;
        final next = ref.read(speechRateProvider.notifier).next();
        ref.read(speechProvider).rate = next;
        setState(() {});
        _step('Speech rate', '${(next * 100).round()} percent');
      case 'Clear chat history':
        if (_awaitingClearConfirm) {
          ref.read(chatHistoryProvider.notifier).clear();
          _awaitingClearConfirm = false;
          _buzz(HapticPattern.confirm);
          _speak('Chat history cleared.');
        } else {
          _awaitingClearConfirm = true;
          _speak(
              'Clear all chat history? Tap again to confirm, or swipe away to cancel.');
        }
    }
  }

  int _optionCount(String item) {
    switch (item) {
      case 'Color theme':
        return Palettes.all.length;
      case 'Font':
        return AppFonts.all.length;
      case 'Text size':
        return TextScale.presets.length;
      default:
        return TextSpacings.all.length;
    }
  }

  String _optionLabel(String item, int i) {
    switch (item) {
      case 'Color theme':
        return Palettes.all[i].label;
      case 'Font':
        return AppFonts.all[i].label;
      case 'Text size':
        return TextScale.presetLabel(i);
      default:
        return TextSpacings.all[i].label;
    }
  }

  int _currentOption(String item) {
    switch (item) {
      case 'Color theme':
        return Palettes.all
            .indexWhere((p) => p.id == ref.read(paletteProvider).id)
            .clamp(0, Palettes.all.length - 1);
      case 'Font':
        return AppFonts.all
            .indexWhere((f) => f.id == ref.read(fontProvider).id)
            .clamp(0, AppFonts.all.length - 1);
      case 'Text size':
        return TextScale.presetIndexOf(ref.read(textScaleProvider));
      default:
        return TextSpacings.all
            .indexWhere((s) => s.id == ref.read(textSpacingProvider).id)
            .clamp(0, TextSpacings.all.length - 1);
    }
  }

  /// Shows the option on screen. Does not save it.
  void _showOption(String item, int i) {
    switch (item) {
      case 'Color theme':
        ref.read(paletteProvider.notifier).set(Palettes.all[i]);
      case 'Font':
        ref.read(fontProvider.notifier).set(AppFonts.all[i]);
      case 'Text size':
        ref.read(textScaleProvider.notifier).set(TextScale.presets[i]);
      default:
        ref.read(textSpacingProvider.notifier).set(TextSpacings.all[i]);
    }
    setState(() {});
  }

  void _startPick(String item) {
    if (_picking != null || !_previewable.contains(item)) return;
    final at = _currentOption(item);
    setState(() => _picking = _Pick(item, at, at));
    _awaitingClearConfirm = false;
    _buzz(HapticPattern.holdEngaged);
    _speak('Preview. ${const GesturePhrases().swipeLeftRight}, tap to keep, '
        'hold the right edge to cancel. '
        '${OptionPicker.describe(_optionLabel(item, at), at, _optionCount(item))}');
  }

  void _movePick(int delta) {
    final p = _picking;
    if (p == null) return;
    final count = _optionCount(p.item);
    final to = OptionPicker.move(p.index, delta, count);
    if (to == null) {
      _buzz(HapticPattern.edge);
      _speak('${delta > 0 ? 'Last' : 'First'}. '
          '${OptionPicker.describe(_optionLabel(p.item, p.index), p.index, count)}');
      return;
    }
    _showOption(p.item, to);
    setState(() => _picking = p.moved(to));
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    _speak(OptionPicker.describe(_optionLabel(p.item, to), to, count));
  }

  void _confirmPick() {
    final p = _picking;
    if (p == null) return;
    setState(() => _picking = null);
    _buzz(HapticPattern.confirm);
    // Re-speaking the row speaks the kept value ("Color theme: Warm").
    _speak(_label(p.item));
  }

  void _cancelPick() {
    final p = _picking;
    if (p == null) return;
    _showOption(p.item, p.start);
    setState(() => _picking = null);
    _buzz(HapticPattern.back);
    _speak('Cancelled.');
  }

  void _move(int delta) {
    final moved = delta > 0 ? _focus.next() : _focus.previous();
    if (!moved) return;
    _awaitingClearConfirm = false;
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
    _speak(_label(_items[_focus.index]));
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _jumpTap(int i) {
    if (_picking != null) {
      _confirmPick();
      return;
    }
    _focus.jumpTo(i);
    setState(() {});
    _buzz(HapticPattern.select);
    // The jump reads the row, then the choice speaks its new value;
    // a tap is one motion, so only the choice is spoken aloud.
    _activate(_items[i]);
  }

  void _holdRow(int i) {
    _focus.jumpTo(i);
    setState(() {});
    _startPick(_items[i]);
  }

  void _back() {
    if (_picking != null) {
      _cancelPick();
      return;
    }
    _awaitingClearConfirm = false;
    _buzz(HapticPattern.back);
    _speak('Back to Home.');
    unawaited(goBack(context, home: const HomeScreen()));
  }

  void _hold() {
    final rate = ref.read(speechProvider).rate;
    _speak('Settings. Speaking at ${speechSpeedLabel(rate)}. '
        '${const GesturePhrases().holdToChangeSpeed} '
        'Currently focused: ${_label(_items[_focus.index])}.');
  }

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
    setState(() {});
  }

  void _onGesture(Gesture gesture) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.right):
        if (_picking != null) _movePick(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.left):
        if (_picking != null) _movePick(-1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        if (_picking == null) _move(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        if (_picking == null) _move(-1);
      case Tap(zone: Zone.center):
        if (_picking != null) {
          _confirmPick();
        } else {
          _buzz(HapticPattern.select);
          _activate(_items[_focus.index]);
        }
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _speak(_label(_items[_focus.index]));
      case LongPress(zone: Zone.rightEdge):
        _back();
      case LongPress(zone: Zone.center):
        if (_picking == null) _startPick(_items[_focus.index]);
      case ThreeFingerTap():
        _speak(_label(_items[_focus.index]));
      case ThreeFingerHold():
        _hold();
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
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    ref.watch(soundCuesProvider);
    ref.watch(textScaleProvider);
    ref.watch(textSpacingProvider);
    ref.watch(reduceMotionProvider);
    ref.watch(speechRateProvider);
    final picking = _picking;
    return ResonantScaffold(
      title: 'Settings',
      subtitle: picking != null
          ? 'Previewing: ${_optionLabel(picking.item, picking.index)}. Tap to keep'
          : 'Speech speed: ${ref.watch(speechProvider).rate}x',
      onBack: _back,
      backAnnouncement:
          picking != null ? 'Cancelled.' : 'Back to Home.',
      child: ListShortcuts(
        onMove: _move,
        onActivate: () {
          if (_picking != null) {
            _confirmPick();
          } else {
            _buzz(HapticPattern.select);
            _activate(_items[_focus.index]);
          }
        },
        onBack: _back,
        child: GestureSurface(
          twoFingerSwipe: true,
          ignoreChildGestureAt: _onRow,
          onGesture: _onGesture,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FirstVisitGuide(key: _guideKey, screen: GuideScreen.settings),
              Text(
                const GesturePhrases().holdToChangeSpeed,
                style: TextStyle(
                  fontFamily: font.family,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  height: 24 / 18,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                _SettingsRow(
                  key: _keys[i],
                  label: _label(_items[i]),
                  focused: i == _focus.index,
                  index: i,
                  previewable: _previewable.contains(_items[i]),
                  onTap: () => _jumpTap(i),
                  onHold: () => _holdRow(i),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// One setting: the label and its value in a card, the focused one
/// inverted like Home. Previewable rows start a preview on hold; the
/// hold wins the arena, so lifting the finger does not also tap.
class _SettingsRow extends ConsumerWidget {
  const _SettingsRow({
    super.key,
    required this.label,
    required this.focused,
    required this.index,
    required this.previewable,
    required this.onTap,
    required this.onHold,
  });

  final String label;
  final bool focused;
  final int index;
  final bool previewable;
  final VoidCallback onTap;
  final VoidCallback onHold;

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
            onLongPress: previewable ? onHold : null,
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
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: font.family,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 34 / 28,
                    color: focused ? palette.onInk : palette.ink,
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
