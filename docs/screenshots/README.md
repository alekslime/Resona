# Screenshots

Rendered from the real app (sample picture, accessibility fakes for audio) —
not mockups. To regenerate after UI changes:

```bash
cp tool/screenshots_test.dart test/screenshots_test.dart
flutter test --update-goldens test/screenshots_test.dart
mv test/screenshots_test.dart tool/screenshots_test.dart
```

The generator lives in `tool/` so golden comparisons never slow down or
flake the normal `flutter test` run.
