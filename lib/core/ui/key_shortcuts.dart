import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard control for judges, testers and desktop browsers: every
/// list behaves the same. Up/down moves focus, Enter opens, Escape
/// goes back. Arrow keys mirror the two-finger swipes (down is next).
/// The quiz reader adds right-arrow to submit.
class ListShortcuts extends StatelessWidget {
  const ListShortcuts({
    super.key,
    required this.onMove,
    required this.onActivate,
    this.onBack,
    this.onRight,
    required this.child,
  });

  final void Function(int delta) onMove;
  final VoidCallback onActivate;
  final VoidCallback? onBack;
  final VoidCallback? onRight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowDown):
            const _MoveIntent(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp):
            const _MoveIntent(-1),
        const SingleActivator(LogicalKeyboardKey.enter):
            const _ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter):
            const _ActivateIntent(),
        if (onRight != null)
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              const _RightIntent(),
        if (onBack != null)
          const SingleActivator(LogicalKeyboardKey.escape): const _BackIntent(),
      },
      child: Actions(
        actions: {
          _MoveIntent: CallbackAction<_MoveIntent>(
            onInvoke: (intent) => onMove(intent.delta),
          ),
          _ActivateIntent: CallbackAction<_ActivateIntent>(
            onInvoke: (_) {
              onActivate();
              return null;
            },
          ),
          if (onRight != null)
            _RightIntent: CallbackAction<_RightIntent>(
              onInvoke: (_) {
                onRight!();
                return null;
              },
            ),
          if (onBack != null)
            _BackIntent: CallbackAction<_BackIntent>(
              onInvoke: (_) {
                onBack!();
                return null;
              },
            ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _MoveIntent extends Intent {
  const _MoveIntent(this.delta);
  final int delta;
}

class _ActivateIntent extends Intent {
  const _ActivateIntent();
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _RightIntent extends Intent {
  const _RightIntent();
}

/// App-wide shortcuts. `?` (and F1) opens the shortcut card, everywhere
/// except while typing: a question mark in a text field must stay text.
/// Sits above the app, so the dialog opens through [navigatorKey].
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child, this.navigatorKey});

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  static bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.slash, shift: true):
            _HelpIntent(),
        SingleActivator(LogicalKeyboardKey.f1): _HelpIntent(),
      },
      child: Actions(
        actions: {
          _HelpIntent: CallbackAction<_HelpIntent>(
            onInvoke: (_) {
              if (_typing()) return null;
              final dialogContext = navigatorKey?.currentContext ?? context;
              if (dialogContext.mounted) {
                showDialog(
                  context: dialogContext,
                  builder: (_) => const ShortcutHelpDialog(),
                );
              }
              return null;
            },
          ),
        },
        // Holds focus when no screen does; a screen's own autofocus
        // node attaches later and takes over.
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}

/// What the keyboard can do, on one card.
class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key});

  static const _rows = [
    ('Up / Down', 'Move focus through the list'),
    ('Enter', 'Open the focused line'),
    ('Escape', 'Go back'),
    ('? or F1', 'This card'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (keys, does) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: text.bodyMedium,
                  children: [
                    TextSpan(
                      text: '$keys  ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: does),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
