# Filming day — Nov 3 (interview + demo)

Two videos, one day. Shoot the **demo first** (it needs the working app and a quiet room),
then the interview while the demos are still fresh in your head.
Submissions close **Nov 4, 9:00 PM ET** — filming Nov 3 leaves Nov 4 for editing and submitting.

## Before Nov 3 (Nov 1–2)
- [x] `cd backend && npm test` and `flutter test` both green (44 + 111, Nov 1).
- [ ] `npm run check:api`, then run **one real picture end-to-end on the phone you will film with**:
      gallery chart (summary + one rank) → hero analyze → explore → Lesson (2 steps) →
      Quiz (1 find-it wrong-then-right, 1 say-it) → hold-to-ask with one follow-up ("and why?").
      This is the exact demo path — rehearse it twice.
- [ ] Pick the hero picture now (a labelled diagram films best: water cycle or human lungs).
      **Pre-analyze it once** so the backend cache is warm; still film one honest fresh analyze
      (the app now counts parts off out loud — "2 of 6" — while it loads).
- [ ] If the public backend is live, film against it (proves the link); otherwise same-Wi-Fi
      backend with the exact `--dart-define=API_BASE=...` build, and say the link in the close.
- [ ] Charge phone + headphones (the stereo pitch demo only lands on headphones/speakers in stereo),
      clean lens, Do Not Disturb on, brightness up.

## Demo video (~3 min, script in DEMO_SCRIPT.md)
- [ ] Record phone screen **with audio**; explore segment with screen covered / eyes closed.
- [ ] Beats: problem (0:15) → instant samples + chart ranks (0:35) → hero explore with
      spoken progress (1:00) → Show outlines for sighted viewers (2:00) → **Lesson: two steps** →
      **Quiz: one wrong, one right** (let the correct/incorrect buzzes be heard) →
      **Tutor: question + follow-up** → how Meta models chain → close.
- [ ] First line is the disclosure line in `docs/HACKATHON.md`. Do not skip it.
- [ ] Keep every claim true to what is on screen. If a take has a SAM miss, re-take with the hero picture.
- [ ] Do not demo Talk live: the button is gated until the first on-phone call passes.

## Roll checklist (day of, before each take)
- [ ] Do Not Disturb on, ringer up (screen recording must capture app audio), brightness up.
- [ ] Headphones plugged in and worn; clap once on mic so audio sync can be checked.
- [ ] Backend reachable: ask one throwaway question in Chat — no "Offline" banner
      means the backend is live (there is no server dot; the banner is the
      only connectivity signal). Hero picture pre-analyzed.
- [ ] Screen cover (cloth) within reach for the eyes-closed segment.
- [ ] 2 s of silence before the disclosure line; room tone 10 s at the end.

## Interview video (aesthetic)
- [ ] Shoot after the demo, same light: golden hour / window light, plain background, phone on a
      tripod at eye level, braille-R shirt/plain dark top, no logos.
- [ ] Talking points (pick 4–5, 20–30 s each): why blind students + pictures; "alt text stops where
      learning starts"; Spark decides *what*, SAM decides *where*, the mask is the teacher;
      porting Resonant-AI (lessons/quiz/voice) onto pictures; chart ranks from masks alone;
      what SAM still gets wrong; what's next (proving live voice, a library that lasts).
- [ ] Film each answer twice; leave 2 s of silence head/tail for cuts; room tone 10 s.
- [ ] B-roll while you're set up: finger exploring with headphones on, lesson stepping, quiz buzz,
      the backend terminal answering. 10 s each, no talking.

## After filming (Nov 3 evening – Nov 4)
- [ ] Back up raw files in two places before editing anything.
- [ ] Nov 3 evening / Nov 4 morning: edit, captions on everything (your audience includes
      deaf-blind-adjacent judges — captions are on-brand), README screenshots from the hero picture.
- [ ] Nov 4: fresh-clone check + **submit by afternoon ET** (deadline 9:00 PM ET, see HACKATHON.md).
