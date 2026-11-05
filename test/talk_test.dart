import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/ui/resonant_dots.dart';
import 'package:resonant/features/touch/presentation/live_talk_screen.dart';

// The live room itself does real network in initState, so it stays out of
// widget tests. What is tested: the dots mapping and the caption line.

void main() {
  group('talk dots', () {
    test('connecting orbits, speech speaks, mic listens', () {
      expect(
        talkDotsState(connecting: true, agentSpeaking: true, micOn: true),
        DotsState.thinking,
      );
      expect(
        talkDotsState(connecting: false, agentSpeaking: true, micOn: true),
        DotsState.speaking,
      );
      expect(
        talkDotsState(connecting: false, agentSpeaking: false, micOn: true),
        DotsState.listening,
      );
      expect(
        talkDotsState(connecting: false, agentSpeaking: false, micOn: false),
        DotsState.idle,
      );
    });
  });

  group('user line', () {
    testWidgets('a caption speaks right-aligned', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: UserLine('hello there')),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('hello there'));
      expect(text.textAlign, TextAlign.right);
      expect(text.style!.fontSize, 19);
      expect(text.style!.fontWeight, FontWeight.w600);
    });
  });
}
