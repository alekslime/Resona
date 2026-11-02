import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/ui/resonant_controls.dart';
import '../../../core/ui/resonant_scaffold.dart';

/// The first name used in the Chat greeting ("Hi Ana!").
/// Blank = the generic greeting.
class NameSetupScreen extends ConsumerStatefulWidget {
  const NameSetupScreen({super.key});

  @override
  ConsumerState<NameSetupScreen> createState() => _NameSetupScreenState();
}

class _NameSetupScreenState extends ConsumerState<NameSetupScreen> {
  late String _name;

  @override
  void initState() {
    super.initState();
    _name = ref.read(userNameProvider) ?? '';
  }

  void _save() {
    ref.read(userNameProvider.notifier).set(_name);
    Navigator.of(context).pop();
  }

  void _clear() {
    ref.read(userNameProvider.notifier).clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ResonantScaffold(
      title: 'Your name',
      subtitle: 'Shown in the Chat greeting',
      onBack: () => Navigator.of(context).pop(),
      backAnnouncement: 'Back to Settings.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            ResonantTextField(
              value: _name,
              onChanged: (v) {
                final capped = v.length > 30 ? v.substring(0, 30) : v;
                if (capped != _name) setState(() => _name = capped);
              },
              label: 'First name',
              keyboardType: TextInputType.name,
              onSubmitted: (_) => _save(),
              autoFocus: true,
            ),
            const SizedBox(height: 20),
            ResonantButton(text: 'Save', onPressed: _save),
            const SizedBox(height: 12),
            ResonantButton(
                text: 'Clear', filled: false, onPressed: _clear),
          ],
        ),
      ),
    );
  }
}
