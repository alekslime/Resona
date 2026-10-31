# Filming day — Nov 2 (interview + demo)

Two videos, one day. Shoot the **demo first** (it needs the working app and a quiet room),
then the interview while the demos are still fresh in your head.

## Before Nov 2 (Oct 31 – Nov 1)
- [ ] `cd backend && npm test` and `flutter test` both green.
- [ ] `npm run check:api`, then run **one real picture end-to-end on the phone you will film with**:
      analyze → explore → Lesson (2 steps) → Quiz (1 find-it wrong-then-right, 1 say-it) →
      hold-to-ask with one follow-up ("and why?"). This is the exact demo path — rehearse it twice.
- [ ] Pick the hero picture now (a labelled diagram films best: water cycle or human lungs).
      **Pre-analyze it once** so the backend cache and the lesson/quiz for it are warm; still film
      one honest fresh analyze if time allows (say "about half a minute" while it loads).
- [ ] Charge phone + headphones (the stereo pitch demo only lands on headphones/speakers in stereo),
      clean lens, Do Not Disturb on, brightness up.
- [ ] Backend running on the same Wi-Fi as the phone; test the exact `--dart-define=API_BASE=...` build.

## Demo video (~3 min, script in DEMO_SCRIPT.md)
- [ ] Record phone screen **with audio**; main segment with screen covered / eyes closed.
- [ ] Beats: problem (0:15) → explore (0:40) → **Lesson: two steps** → **Quiz: one wrong, one right**
      (let the correct/incorrect buzzes be heard) → **Tutor: question + follow-up** → how Meta models
      chain (Spark names, SAM outlines, mask grades the quiz) → close.
- [ ] First line is the disclosure line in `docs/HACKATHON.md`. Do not skip it.
- [ ] Keep every claim true to what is on screen. If a take has a SAM miss, re-take with the hero picture.

## Interview video (aesthetic)
- [ ] Shoot after the demo, same light: golden hour / window light, plain background, phone on a
      tripod at eye level, braille-R shirt/plain dark top, no logos.
- [ ] Talking points (pick 4–5, 20–30 s each): why blind students + pictures; "alt text stops where
      learning starts"; Spark decides *what*, SAM decides *where*, the mask is the teacher;
      porting Resonant-AI (lessons/quiz/voice) onto pictures; what SAM still gets wrong; what's next
      (charts that read values, real-time voice).
- [ ] Film each answer twice; leave 2 s of silence head/tail for cuts; room tone 10 s.
- [ ] B-roll while you're set up: finger exploring with headphones on, lesson stepping, quiz buzz,
      the backend terminal answering. 10 s each, no talking.

## After filming (Nov 2 evening)
- [ ] Back up raw files in two places before editing anything.
- [ ] Nov 3: edit, captions on everything (your audience includes deaf-blind-adjacent judges —
      captions are on-brand), README screenshots from the hero picture.
- [ ] Nov 4: fresh-clone check + submit by afternoon ET (see DAY_PLAN.md).
