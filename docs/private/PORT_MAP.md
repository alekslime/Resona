# Port map: Resonant-AI (Kotlin) -> this Flutter app

Spec is `C:\Users\aleks\Resonant-AI`, routes from `ui/nav/Navigation.kt`,
home from `ui/home/HomeScreen.kt`. Nothing here changes the old repo.
Transient working doc: delete when the port lands.

## Old route table (spec)

splash -> setup -> onboarding -> home. Back pops, else lands home.
Transitions: 250 ms fade + 0.96 scale; reduce motion = plain cut.

| Old route | Old screen | Port to | Slice | Status |
| --- | --- | --- | --- | --- |
| home | Chat, Lessons, Quiz, Profile, Settings, Quit | home_screen.dart, 8 items (below) | 1 | done (surface gestures in 5) |
| chat (liveMode) | hero + answer + history + voice commands | new chat_screen.dart on our backend/Meta API | 2 | done |
| lessons | built-in library + own materials | lessons_screen.dart (built-ins only) | 3 | done |
| lesson_mode/{id} | Manual / Auto picker | lesson_mode_screen.dart | 3 | done |
| lesson/{id}?auto | section reader, auto-advance | lesson_screen.dart | 3 | done |
| quiz_browser | built-in sets | quiz_browser_screen.dart | 4 | done |
| quiz/{id} | browse options, tap selects, swipe right submits | quiz_reader_screen.dart | 4 | done |
| quiz_results/{c}/{t} | score + retry-missed offer | quiz_results_screen.dart | 4 | done |
| quiz_review | QuizScreen over missed questions | reviewSet() into the reader | 4 | done |
| profile | braille avatar, stats, milestones, How am I doing | profile_screen.dart + stores | 4 | done |
| settings (17 rows) | see row map below | extend settings_screen.dart | 5 | done (9 rows; rest omitted, below) |
| debug | connection info + server setup entry | — | 5 | omitted: no debug bus in this tree |
| name_setup | set your name | name_setup_screen.dart | 4c | done |
| server_setup | LiveKit/Whisper URLs | — | - | omitted: build-time Env instead |
| setup | first-run setup | — | 5b | omitted: no budget |
| onboarding | gesture tutorial | — | 5b | omitted: no budget |
| talkback notice | TalkBack explain + settings link | — | 5 | omitted with the tutorial |

Settings rows omitted: Replay Tutorial (no tutorial), Add material (file
picker = new package), Voice engine (Android TTS; server-side here), Live
voice/speed/mic (on-device live mode), Offline voice model + On-phone AI
(model downloads; server-side here), Debug Mode (no debug bus). The
Speech rate row is this app's own, driving the same rate the edge drag
adjusts.

## Home items (new)

Old: Chat, Lessons, Quiz, Profile, Settings, Quit.
New: Chat, Lessons, Quiz, Pictures, Notes, Profile, Settings, Quit.
Pictures (SAM explore) and Notes (study notes) have no old counterpart and
stay as their own entries. Talk folds into Chat: old Chat IS the live voice
mode (`liveMode = true`), and picture context rides along as the old
`activeMaterialId` does (ours: last explored picture, else "explore first").

## Lessons content (port verbatim from LessonData.kt)

Binary Search (5 sections), Photosynthesis (sections), whatever else
LessonData holds — read fully in slice 3. Own-material import (file picker
+ PDF extract: MaterialImporter/MaterialParser/PdfTextExtractor) is
deferred: no new packages allowed, and it is a slice of its own.

## Quiz content (port verbatim from QuizData.kt)

Photosynthesis basics, Cells and their parts, Energy in ecosystems, Plant
adaptations, sample quiz — read fully in slice 4.

## Settings row map

Old 17 rows -> ours. Kept: Sound cues, Color theme, Font, Text size, Text
spacing, Reduce motion. Added: Replay Tutorial, Your name, Clear chat
history, Debug Mode. Kept ours: Speech rate (our voice stack has no
Voice engine / Live voice / Live speed / Live mic split). Deferred with
material import: Add material from a file. Not ported (old on-device
stack; ours is server voices): Voice engine, Live voice, Live mic,
Offline voice model, On-phone AI.

## Stores (port as pure Dart behind interfaces, in-memory first)

ActivityStore (streak, lessons/quizzes done, materials, listening seconds),
MilestoneStore (14 milestones, announce-once), QuizProgressStore (per-set
best), ChatHistoryStore (exchanges + clear). No shared_preferences: no new
packages allowed, so no disk persistence until a later slice adds it.

## Conflicts already decided

- Old quiz is multiple-choice from QuizData; ours is find-the-part/say
  graded by the backend. Both stay: browser lists built-in sets (old
  behavior); picture find-quiz stays in the Pictures touch flow.
- OfflineAnswers.kt (offline fallback Q&A) becomes our tutor-chat
  fallback when the server is unreachable.
- Old AudioManager queue (setQueue/index/autoAdvance) is NOT ported
  whole; screens drive speech through our SpeechOutput + MenuFocus,
  extended only where a screen needs queue semantics.
- server_setup editing is dropped: our API base is build-time (Env).
  Debug shows connection info instead.
