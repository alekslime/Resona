import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme/resonant_theme.dart';
import 'features/touch/presentation/pictures_screen.dart';

class ResonantApp extends ConsumerWidget {
  const ResonantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    return MaterialApp(
      title: 'Resonant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette),
      home: const PicturesScreen(),
    );
  }
}
