import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/resonant_theme.dart';
import 'features/touch/presentation/home_screen.dart';

class ResonantApp extends ConsumerWidget {
  const ResonantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    return MaterialApp(
      title: 'Resonant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette, font),
      home: const HomeScreen(),
    );
  }
}
