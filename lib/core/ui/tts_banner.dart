/// The voice-missing banner, ported from Resonant's TtsUnavailableBanner.
///
/// This app is built around speech being available. If the engine hasn't
/// become ready a few seconds after launch, something is genuinely wrong
/// (no text-to-speech engine installed or enabled) rather than still
/// warming up, so this shows it and buzzes once instead of leaving the
/// person guessing why nothing talks.
///
/// The grace period only runs while the app is in the foreground.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/haptics.dart';

class TtsUnavailableBanner extends StatefulWidget {
  const TtsUnavailableBanner({
    super.key,
    required this.ready,
    required this.haptics,
  });

  /// Whether the speech engine is ready. The banner watches it.
  final ValueNotifier<bool> ready;
  final Haptics haptics;

  @override
  State<TtsUnavailableBanner> createState() => _TtsUnavailableBannerState();
}

class _TtsUnavailableBannerState extends State<TtsUnavailableBanner>
    with WidgetsBindingObserver {
  bool _show = false;
  bool _gone = true;
  Timer? _grace;

  bool get _resumed =>
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.inactive &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.detached;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.ready.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ready.removeListener(_check);
    _grace?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _check();
  }

  void _check() {
    if (widget.ready.value) {
      _grace?.cancel();
      if (_show && mounted) setState(() => _show = false);
      return;
    }
    _grace?.cancel();
    if (_show || !_resumed) return;
    _grace = Timer(const Duration(seconds: 4), () {
      // The buzz plays once, when the banner first appears.
      if (!widget.ready.value && !_show && _resumed && mounted) {
        setState(() {
          _show = true;
          _gone = false;
        });
        widget.haptics.play(HapticPattern.error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final banner = Container(
      width: double.infinity,
      color: const Color(0xFF2A0000),
      padding: const EdgeInsets.all(16),
      child: Text(
        'Voice is unavailable. Check that a text-to-speech engine is installed and enabled in your device settings.',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white),
      ),
    );
    if (reduce) return _show ? banner : const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      onEnd: () {
        if (!_show && mounted) setState(() => _gone = true);
      },
      child: _gone && !_show ? const SizedBox.shrink() : banner,
    );
  }
}
