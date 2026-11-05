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
  voice tutor chat — see the "Ported from Resonant-AI" table in `README.md`.**
  **Phase 0 inventory done 2026-11-01: `alekslime/Resonant-AI` was cloned outside this repo and its
  README/screens read. Its lesson, quiz, chat and live-agent flows match what was ported. Two deliberate
  substitutions: Muse Spark thinks instead of the old local model, and Piper speaks instead of the old
  PC voice — same architecture (Silero VAD → speech-to-text → model → text-to-speech), new code.**
- The old LiveKit agent was **not** copied or revived as code. A new agent (`agent/agent.py`) was
  written fresh for Talk live, using a new LiveKit project's keys, which live only in the gitignored
  `backend/.env`. First on-phone call still to be made; until it passes, the proven tutor is the
  hold-to-talk chat.
- Keep dated commits. A history that shows the new work arriving is your proof.
- Nothing from the earlier app's `agent/.env` was brought into this repo.
- Read whether the rules say anything about AI-assisted code. The README credits Claude for the initial scaffold; edit it to match what is true by the time you submit.

## Deadline

Submissions close Nov 4, 9:00 PM ET, which is 3:00 AM on Nov 5 in Tirana (US clocks go back on Nov 1).
Aim to submit by the afternoon of Nov 4 ET and polish only after that.
