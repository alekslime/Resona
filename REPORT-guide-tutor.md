# Report: guide-tutor (voice tutor upgrade of guide mode)

Branch `guide-tutor`, from tag `pre-guide-upgrade`. All work was pure Dart
behind the existing interfaces; no new packages, no backend/model/network
calls in per-move code. `flutter test` (153 tests, was 114) and
`flutter analyze` are green. Each slice was committed as tests-then-impl
and pushed after going green. No call sites changed: `TouchSession` gained
only optional/additive API (`nowMs` clock, `TouchView.guideHelp`), and
`Cues` gained one method implemented in all three implementers.

## What was done

1. Fuzzy "where is X" matching (`guide_match.dart`). Word-level Levenshtein
   similarity (0.7 best word + 0.3 mean over label words) tolerates STT
   slips ("artheria" finds "artery", verified in tests). Top-two scores
   within 0.08 both above the 0.6 threshold ask
   "Did you mean A or B?" (e.g. "lung" with left/right lung). Below
   threshold: "I could not find that part in this picture." Neither path
   calls the tutor. Exact and partial matches behave as before.
2. Live guidance (`guide_path.dart` + session). Each region's mask-edge
   points are precomputed once per picture into a cache (capped at 400
   points per region); every move scans only the target's cached points
   for the nearest one, so direction/distance go to the part itself, never
   the (possibly off-part) box centre. Sixteen short sectors
   ("right", "up and a little left", ...) plus "almost there" when very
   close. Speech only on sector/bucket change or after ~1.5 s of movement
   (injectable `nowMs` clock; production uses wall time). Arrival clears
   the guide before its delayed message fires, so live cues can never talk
   over it. New `Cues.proximity(closeness 0..1)` tone rises in 5 cached
   steps (600-1200 Hz) as the finger nears; implemented in
   `AudioPlayersCues` (cached like other cues), no-op in `NoCues`, logged
   in `FakeCues`. Rest and guide-start now also measure to the nearest
   mask point but keep the old sentence shape.
3. Arrival teaching. On landing: "You found the X", its `spoken` line, the
   `aroundWords` sentence, then "Next is the Y. Say "where is the Y?" to
   keep going." for the next part in reading order, or "That was the last
   part." Nothing outside `Region` text except part names and fixed
   carrier phrases; chart ranks untouched.
4. Fading help (`guide_help.dart`). Per-part levels full -> hints -> none.
   Hints: quiet while moving (no speech, no tone); direction on rest or
   explicit "hint" ask. None: "Keep looking for the X." everywhere, arrival
   still celebrates. Fast (<=15 s, no wrong taps) lowers one step; wrong
   (centre-tap on another part mid-hunt) or slow (>40 s) raises one step;
   medium keeps. Re-asking for the same target mid-hunt gives a hint
   without restarting the timer. Level exposed as `TouchView.guideHelp`
   (current or last target; default full). Levels reset on new picture.

## What failed or was skipped

- Nothing was skipped: all four slices are implemented, tested, green.
- One mid-slice test failure, fixed before committing the slice: averaging
  word scores let "lung" match "left lung" (0.63) but not "right lung"
  (0.50, below threshold), so no ambiguity was reported. Scoring is now
  0.7*best + 0.3*mean, which reports the pair as ambiguous while still
  letting explicit "left lung" win outright. No slice needed more than one
  fix; the stop rule never triggered.
- Existing guide tests all still pass, plus new regression tests locking
  "where is the sun" start/rest/arrival wording and the correct cue.

## Decisions made without asking

- Thresholds: match 0.6 / ambiguity margin 0.08; fast <=15 s / slow >40 s;
  live repeat ~1.5 s; 400 boundary points max; 5 proximity pitch steps.
  All are constants, tunable after phone trials.
- Guide triggers kept as the original four ("find", "where is",
  "where's", "guide me"); no new trigger phrases.
- Guide-start sentence changed from "then rest and I will point you" to
  "and I will guide you" since guidance is now live. Rest keeps the long
  8-sector sentence; moves use the short 16-sector cues.
- Unknown/ambiguous asks never reach the tutor; same-target re-ask is a
  hint (timer not reset); switching targets starts a fresh timed hunt.
- Wrong find = centre-tap on a non-target part mid-hunt (taps on empty
  space don't count). Medium-speed clean finds hold the level.
- Pure-find (`none`) gives no direction even when explicitly asked for a
  hint ("Keep looking for the X."); struggling (slow) raises the level
  for next time. Arrival teaching is identical at all levels.
- Live moves in hints/none play no proximity tone (tones resume on rest
  in hints mode only).

## Changed files

- `lib/features/touch/domain/guide_match.dart` (new): fuzzy matching.
- `lib/features/touch/domain/guide_path.dart` (new): boundary cache,
  nearest point, 16 sectors, buckets, closeness.
- `lib/features/touch/domain/guide_help.dart` (new): levels + transitions.
- `lib/features/touch/application/touch_session.dart`: guide start/rest/
  live/arrival/hint/help logic, `nowMs` clock, `TouchView.guideHelp`.
- `lib/core/services/sound.dart`: `Cues.proximity` + `NoCues` no-op.
- `lib/core/services/audio_cues.dart`: cached proximity tone.
- `test/fakes.dart`: `FakeCues.proximity` logging.
- `test/guide_match_test.dart` (new, 10 tests), `test/guide_live_test.dart`
  (new, 16), `test/guide_arrival_test.dart` (new, 3),
  `test/guide_help_test.dart` (new, 10).

## Follow-up fixes (same branch, after the report)

All five requested fixes, each tests-then-impl, green and pushed per slice.
176 tests total (was 153), `flutter analyze` clean. Line endings verified
uniform per file (repo files CRLF, new files LF); `touch_session.dart` is
not mixed.

1. Tone throttle: the proximity tone replays only when its pitch step
   (0..4, via shared `proximityStep`) changes, with a 150 ms minimum gap;
   a step held inside the gap plays once the gap passes. New
   `test/guide_tone_test.dart`; two `guide_live_test` tone counts updated.
2. `GuideNotFound` falls through to normal tutor chat (guide keeps
   running); "Did you mean A or B?" unchanged. The unknown-part session
   test now expects the fallback plus a guide-preserved check.
3. Hints on pure finds: an explicit hint always speaks a direction and
   raises the stored level for next time (this hunt stays pure otherwise;
   needing the hint blocks the fast-lower so the raise sticks). Past
   20 s without a find, moves and rests say once "Say hint if you want
   help." (asking for a hint marks it taught). New
   `test/guide_hint_test.dart`.
4. Live speech keeps a 700 ms gap (armed by live/rest/hint/nudge speech,
   not by guide-start) and 3-degree hysteresis at sector edges
   (`guideSectorStable`; decisive jumps switch at once). New
   `test/guide_throttle_test.dart`; the nudge test advances past the gap.
5. Answering "did you mean A or B?": the pair stays open for exactly one
   answer (silence keeps it); "first", "second", "option a/b", bare
   "a"/"b", or either part's name starts that hunt, anything else
   dismisses it into normal flow. Guide-start extracted to `_beginGuide`
   so answers share it. New `test/guide_disambiguate_test.dart`.

Decisions: tone-gap compares against the last played step (a held step
re-fires after the gap); hint-in-`none` raises stored level only, current
hunt stays pure; nudge fires on moves and rests and yields its turn to no
other cue; bare "a"/"b" accepted only as the whole utterance; both names
at once resolves nothing. One fix-3 test setup line (touch sky before the
hint ask) rode in the implementation commit after the tests commit.

## Risks you could not verify without a phone

- Feel of the guidance: whether 16 sectors help or overwhelm, and whether
  "almost there" arrives at the right moment while dragging at real speed.
- Tone pitch and timing: 600-1200 Hz steps may be too subtle or too
  insistent on a real speaker; per-move tones could overlap speech.
- Throttling thresholds: 1.5 s repeat and sector/bucket-only speech were
  tuned in tests with a fake clock, not a real finger.
- Thin-part accuracy: nearest-boundary logic is unit-tested on synthetic
  masks, but real SAM masks (holes, speckles, approximate rectangles) may
  guide to odd edge points; needs trying on arteries/rivers/charts.
- Speech-recognition slips on a real microphone: "artheria" is covered,
  but real STT errors (accents, noise, multi-word label mangles) and the
  0.6/0.08 cutoffs need live-mic trials; false did-you-means are possible.
- Help fade pacing: 15 s/40 s and tap-counted wrongness are guesses at
  student rhythm; too fast a fade strands beginners, too slow bores fast
  ones. No persistence between launches (levels reset per picture).
