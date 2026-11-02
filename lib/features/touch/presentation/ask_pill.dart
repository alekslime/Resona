import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/icons.dart';

/// "Ask anything…" — type a question, or tap the mic to ask by voice (same
/// path as tapping the center of the screen). Ported from Resonant's
/// AskPill. Lives outside the GestureSurface on purpose: the gesture
/// detector consumes touches, so a text field inside it could never be
/// focused.
class AskPill extends ConsumerStatefulWidget {
  const AskPill({
    super.key,
    required this.listening,
    required this.onSubmit,
    required this.onMic,
  });

  final bool listening;
  final void Function(String question) onSubmit;
  final VoidCallback onMic;

  @override
  ConsumerState<AskPill> createState() => _AskPillState();
}

class _AskPillState extends ConsumerState<AskPill> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    _controller.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onSubmit(q);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final textStyle = TextStyle(
      fontFamily: font.family,
      fontWeight: FontWeight.w600,
      fontSize: 22,
      color: palette.onBar,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: palette.bar,
        ),
        padding: const EdgeInsets.fromLTRB(22, 6, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Type a question, then press send',
                textField: true,
                child: TextField(
                  controller: _controller,
                  style: textStyle,
                  cursorColor: palette.onBar,
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Ask anything...',
                    hintStyle: textStyle,
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
            ),
            Semantics(
              label: widget.listening ? 'Listening' : 'Ask by voice',
              button: true,
              child: GestureDetector(
                onTap: widget.onMic,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.onBar,
                  ),
                  alignment: Alignment.center,
                  child: MicIcon(tint: palette.bar),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
