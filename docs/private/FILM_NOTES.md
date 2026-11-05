# Film script fidelity notes (Resonant_Product_Demo_Script.docx)

Checked Nov 3 against the app on main. The docx's own rule: "Use the
actual Resonant interface. Do not demonstrate features that are not
implemented yet. Make sure gesture descriptions match the app's real
behavior." Verdicts below are per scene.

## Must fix before filming

### Scene 3 — gesture lines mismatch the app (4 lines)

The film shows five gestures but describes three of them wrongly:

1. "A swipe across the center lets me navigate" — MUST say **two
   fingers**. One finger on the center scrolls; only a two-finger swipe
   moves between items. This is the single most important detail to
   get right. Suggested: "A two-finger swipe across the center moves
   between items — one finger just scrolls."
2. "A single tap gives me tactile feedback" — understates what tap
   does. A center tap is the primary action everywhere (ask, activate,
   select). The haptic is confirmation, not the purpose. Suggested:
   "A tap in the center does the main thing on each screen — asking,
   answering, opening — with a confirming buzz."
3. "The left edge lets me pause or repeat" — tap STOPS speech; there
   is no resume, so "pause" is the wrong word. Double-tap repeats.
   Suggested: "A tap on the left edge stops the voice; double-tap
   repeats what it just said."
4. "On the right, I can adjust the playback speed" — true for
   hold-and-drag, but omits the primary right-edge action: hold = back.
   Suggested: "Hold the right edge to go back; drag up or down while
   holding to retune the voice."

The three-finger line ("repeat content") is accurate for the tap.
Three-finger hold ("where am I") is omitted — fine for film brevity,
as is condensing the tour's eight gestures into five.

### Scene 5 — "continue where I left off" is not implemented for lessons

"I can also return to previous lessons and continue where I left
off." There is NO lesson resume: lessons track finished/not-finished
only. Quizzes DO have continue/retry ("Ready to continue" states plus
"Retry N missed"). Either cut the lesson half of the line or scope it
to quizzes: "I can return to a quiz and retry what I missed."

## Should fix (production, not app)

- **No disclosure line.** DEMO_SCRIPT.md opens with a required
  hackathon disclosure ("Resonant is an app I started before the
  hackathon..."). If this film is hackathon-bound, it needs the same
  first line. If it is a separate product film, ignore this.
- **"Actual Android app" vs iPhone.** The docx calls for Android
  screen recordings; FILMING_NOV3.md plans an iPhone web link. Pick
  one before recording day — the presence/absence of the Talk-live
  button and clipboard behavior differ by platform.
- **Scene 4 needs the server live.** The photosynthesis dialogue works
  as scripted only when the backend tutor answers. Offline, Chat falls
  back to reading the shipped photosynthesis lesson verbatim (with an
  on-screen "Offline" banner) — it will not produce the simplified
  "tiny food factory" explanation. Rehearse against the same backend
  the film uses.

## Verified accurate (no change needed)

- Scene 2: opening a lesson plays real narration; the six shipped
  lessons include photosynthesis, cells, ecosystems, plant
  adaptations, binary search, plate tectonics.
- Scene 4 topic: photosynthesis IS answerable offline from lessons,
  so the scene degrades gracefully rather than dying.
- Scene 5 quizzes (four sets + retry rounds), text sizes, themes,
  fonts, and speech speed in Settings — all implemented.
- Subtitle/audio-cue guidance is consistent with the app's real
  announcements.

## Related staleness in the older docs (fixed separately)

- FILMING_NOV3.md's roll checklist says "Home shows the green server
  dot." No such dot exists anywhere in the UI; the only connectivity
  signal is Chat's offline banner after a failed answer. Fixed in
  place to a real check.
- DEMO_SCRIPT.md's "Show outlines" beat is valid: the explore view
  has a "Show outlines / Hide outlines" button that speaks
  ("All outlines shown." / "Outlines hidden.").
