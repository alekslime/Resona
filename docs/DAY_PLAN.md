# Plan: Oct 29 to Nov 4

Goal: a public repo with a working demo on real pictures, and a 3-minute video, with a day to spare.

**Oct 29 (today)**
- Create the new public repo. Copy these files in. First commit. Do not import any history.
- `npm install`, add your key to `.env`, run `npm run check:api`. This is the one thing the starter has not been run against: it was tested with a stand-in for the Meta API. If a call fails, the error names the model or parameter to fix in `server/meta.js`.
- Run `npm start` and try the sample on a phone.

**Oct 30: real pictures**
- Collect 6 pictures: a bar chart, a pie chart, a labeled biology diagram, a map, a simple photo, a textbook-style figure. Run each through the app.
- Read what Muse Spark proposes as parts. Tighten `PARTS_PROMPT` in `server/meta.js` where labels are vague. Check `skipped` for labels SAM could not match.
- Commit the prompt changes with messages that say what improved.

**Oct 31: the feel**
- Tune vibration lengths, dwell times (800 ms / 1100 ms in `app.js`) and tolerance on a real phone.
- Try Ask with a typed question, then with the microphone over an HTTPS tunnel.
- Add one feature that is clearly yours and new. Good candidates: a "trace the outline" mode that vibrates along a region's edge, or a chart mode that reads values in order when you swipe along bars.

**Nov 1: make it runnable by judges**
- Deploy to any Node host with `MODEL_API_KEY` set as a secret, rate limit on. Put the URL at the top of the README.
- Add a handful of pictures to `public/sample/` only if you own them or they are public-domain; note each source.

**Nov 2: test with the people it is for**
- If you can reach a blind or low-vision student or teacher, watch them use it for ten minutes and write down what confused them. If not, use it with your eyes closed and fix what fails.

**Nov 3: video and README**
- Record `docs/DEMO_SCRIPT.md` on a real phone screen with real audio. Fill in the README with a screenshot or two taken from the running app.
- Do a full fresh-clone install on another machine or folder to prove the README steps work.

**Nov 4: submit early**
- Submit by the afternoon ET. Re-check the public repo opens in a private browser window, the video link works, and no `.env` or key is in the history (`git log -p | grep -i key`).
