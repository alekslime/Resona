# Hackathon compliance

Check this against the Official Rules before you submit. They win over this file.

## Rules you told me apply

You told me the earlier FAQ text was the wrong one and that building on the earlier app is fine. I could not
see the correct rules, so I have not assumed more than that. If the real rules say anything about
repository age, git history, or copied code, follow them over this file.

What holds under any reasonable reading, and is already done in this repo:

1. The README says plainly what came from the earlier app and what was built during the event
   (see "Pre-existing work" in `README.md`).
2. The first line of the video says the same (below).
3. The demo shows the new work: exploring a picture by touch, the Meta pipeline behind it, the sound mapping.
4. The repository is public and contains no keys (`.env` is ignored; `.env.example` is empty).

## First line of the video

> "Resonant is an app I started before the hackathon. I brought over its name, logo, look and gesture
> design. Everything you will see about exploring pictures, from the Meta models to the touch and sound, was
> built during the hackathon."

## Check before you submit

- Keep the Pre-existing work table accurate. If you port more from the earlier app, add it. If you remove something, remove it.
  **Ported 2026-10-31 (behaviour rewritten in Dart/JS, no old code copied): lesson mode, quiz/check-me,
  voice tutor chat — see the "Ported from Resonant-AI" table in `README.md`. Phase 0 inventory of
  `alekslime/Resonant-AI` (clone it outside this repo) is still owed: confirm its lesson/quiz/agent
  flows match what was ported, and adjust wording/prompts if they differ.**
- The old LiveKit agent was **not** revived: the tutor is hold-to-talk multi-turn chat over the
  device mic/speaker. If that changes, rotate the old LiveKit keys first (see below).
- Keep dated commits. A history that shows the new work arriving is your proof.
- The earlier app's `agent/.env` held real LiveKit keys. Rotate them, and do not add anything from that file here.
- Read whether the rules say anything about AI-assisted code. The README credits Claude for the initial scaffold; edit it to match what is true by the time you submit.

## Deadline

Submissions close Nov 4, 9:00 PM ET, which is 3:00 AM on Nov 5 in Tirana (US clocks go back on Nov 1).
Aim to submit by the afternoon of Nov 4 ET and polish only after that.
