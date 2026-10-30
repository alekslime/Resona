# Plan: Oct 30 to Nov 4

Goal: a public repo, a link an iPhone can open, an Android build, and a 3-minute video, with a day to spare.

**Oct 30 (today): make it run**
- Install Flutter if you have not. Run `tool/setup.sh`, then `flutter test`. **This is the first time the Flutter layer is compiled.** The pure-Dart core (gestures, hit-testing, the session, sound) is already tested; expect a few compile errors in the plugin and widget code (version differences, an import). Fix them, they are small.
- `cd backend && npm install && cp .env.example .env`, add your key, `npm run check:api`.
- `flutter run` on a real Android phone, open the sample, drag a finger over it.

**Oct 31: real pictures, real feel**
- Run six pictures through it: a bar chart, a pie chart, a labelled diagram, a map, a photo, a textbook figure. Tighten `PARTS_PROMPT` in `backend/server/meta.js` where labels are vague; check `skipped`.
- On the phone, tune what you can feel and hear: `GestureConfig` timings, `hapticMsFor`, `pitchForY`, the stereo width. Headphones on.

**Nov 1: the iPhone route**
- `flutter build web --release`, deploy the backend with the web build, open it on a real iPhone. Fix what breaks. If you have a Mac and an Apple Developer account, do the TestFlight build too.
- Add one thing that is clearly new: tracing a part's outline by vibration, or a chart mode that reads values in order as you slide along bars.

**Nov 2: test with the people it is for**
- Ten minutes with a blind or low-vision student or teacher if you can reach one; otherwise eyes closed and headphones on. Write down what confused you.

**Nov 3: video and README**
- Record `docs/DEMO_SCRIPT.md` on a real phone, with the screen covered for the main demo. Add two real screenshots to the README. Do a fresh-clone install to prove the steps work.

**Nov 4: submit early**
- Submit by the afternoon ET. Check the repo opens in a private window, the link works on an iPhone, and no key is anywhere in the history (`git log -p | grep -i -E "key|secret"`).
