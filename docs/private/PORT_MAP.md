# Port map: Resonant-AI (Kotlin) -> this Flutter app

Spec is `C:\Users\aleks\Resonant-AI`, routes from `ui/nav/Navigation.kt`,
home from `ui/home/HomeScreen.kt`. Nothing here changes the old repo.
Transient working doc: delete when the port lands.

## Old route table (spec)

splash -> setup -> onboarding -> home. Back pops, else lands home.
Transitions: 250 ms fade + 0.96 scale; reduce motion = plain cut.

| Old route | Old screen | Port to | Slice |
| --- | --- | --- | --- |
| home | Chat, Lessons, Quiz, Profile, Settings, Quit | home_screen.dart, 8 items (below) | 1 |
| chat (liveMode) | hero + answer + history + voice commands | new chat_screen.dart on our backend/Meta API | 2 |
| lessons | built-in library + own materials | lessons_screen.dart (built-ins only) | 3 |
| lesson_mode/{id} | Manual / Auto picker | lesson_mode_screen.dart | 3 |
| lesson/{id}?auto | section reader, auto-advance | lesson_screen.dart | 3 |
| quiz_browser | built-in sets | quiz_browser_screen.dart | 4 |
| quiz/{id} | browse options, tap selects, swipe right submits | quiz_screen.dart | 4 |
| quiz_results/{c}/{t} | score + retry-missed offer | quiz_results_screen.dart | 4 |
| quiz_review | QuizScreen over missed questions | same, data-only route arg | 4 |
| profile | braille avatar, stats, milestones, How am I doing | profile_screen.dart + stores | 4 |
| settings (17 rows) | see row map below | extend settings_screen.dart | 5 |
| debug | connection info + server setup entry | debug_screen.dart (info only) | 5 |
| name_setup | set your name | name_setup_screen.dart | 5 |
| server_setup | LiveKit/Whisper URLs | NOT ported (info lives in debug) | - |
| setup | first-run setup | setup_screen.dart if budget allows | 5b |
| onboarding | gesture tutorial | onboarding_screen.dart if budget allows | 5b |
| talkback notice | TalkBack explain + settings link | fold into settings Replay Tutorial | 5 |

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
