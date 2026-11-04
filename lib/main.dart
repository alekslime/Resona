import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/env.dart';
import 'features/touch/data/http_touch_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Warm the backend before the first real request: silent, errors ignored.
  // The health check never throws; a sleeping server just wakes up.
  unawaited(HttpTouchRepository(baseUrl: Env.apiBase).health());
  runApp(const ProviderScope(child: ResonantApp()));
}
