# Resonant

**Learn by sound and touch.** Drag a finger across a picture and feel its parts.

Diagrams, charts and photos are the part of school that screen readers cannot reach. Alt text says
"a diagram of the water cycle" and stops. Resonant turns the picture itself into something a blind
student can explore. Each part speaks its name, buzzes under the fingertip (bigger parts buzz longer,
so size can be felt), and plays a tone whose **pitch is its height** on the page and whose **stereo
position is left to right**, so the whole picture can be heard as well as felt. Rest on empty space and
it says which way to walk to the nearest part.

The logo is the letter R in braille (⠗: dots 1-2-3-5), because sound and touch resonate through everything.

## Pre-existing work

Resonant began as an Android app (Kotlin and Jetpack Compose) that I started **before** the
hackathon, for blind students to learn lessons by voice and gesture. That app is not part of this
repository and none of its code is copied in. These things were **carried over from it and rewritten in
Dart**:

| Carried over from the earlier app | Where it lives here |
| --- | --- |
| The name, the braille R logo and the dot animation geometry | `lib/core/ui/resonant_dots.dart`, `assets/brand/` |
| Colour palettes, shapes and sizes (four of its themes) | `lib/core/theme/` |
| Fonts (Metropolis, Atkinson Hyperlegible) | `assets/fonts/`, see `NOTICE.md` |
| Gesture grammar: zones, timings, swipe inversion, hold-to-adjust-speed, three-finger gestures | `lib/features/touch/gestures/` |
| The haptic vocabulary and its matching sound cues, and the stereo-panning rule | `lib/core/services/haptics.dart`, `sound.dart` |

**Built during the hackathon** (everything else): the Muse Spark + SAM 3.1 backend that turns any
picture into touchable regions; exploring a picture with one finger (the explore gestures, mask
hit-testing, the fingertip-size haptic, rest-to-read, nearest-part directions); the height-to-pitch and
left-right-to-stereo sound mapping; hold-to-ask questions about the part under your finger; stepping
through parts from the edge; the Flutter app and its architecture, for Android, iPhone and web; and all
the tests.

**Ported from Resonant-AI during the hackathon, rewritten in Dart/JS** (behaviour and wording only,
no old code copied; inventoried in `docs/HACKATHON.md`):

| Ported feature | Where it lives here |
| --- | --- |
| Lesson mode: guided steps through content, swipes navigate | `lib/features/learn/`, `POST /api/lesson` |
| Quiz / check-me: correct–incorrect haptic and sound feedback, score | `lib/features/learn/`, `POST /api/quiz`, `POST /api/grade` |
| Voice tutor chat (the old LiveKit agent, as hold-to-talk multi-turn chat) | `TouchSession` history + `POST /api/chat` |

## How it works

```
 picture ──► Muse Spark 1.3 ──► title, overview, and a list of parts
                                (short noun phrases + what to say about each)
        │
        └──► SAM 3.1, once per part ──► exact pixel mask of every match
                                          │  shrunk to a 96-cell grid per part
                                          ▼
   phone: finger position → which mask is under it → speak, vibrate, play a tone, outline the part
```

- **Muse Spark** (`muse-spark-1.3`) reads the picture and decides what its parts are, in reading
  order. It also writes the guided lesson and the quiz from those parts (text-only calls, so they
  cost a fraction of an analysis), grades spoken answers, and answers spoken questions as a
  multi-turn tutor, using the part you last touched and the conversation so far as context.
- **SAM 3.1** (`sam-3.1`) turns each part name into pixel-accurate masks. The mask is what lets a finger
  land on a river or a lung, not just a rectangle. It is also what grades "find-it" quiz questions:
  the app hit-tests your finger against the mask, on the phone, for free.
- The two chain the way Meta's docs suggest: Muse Spark decides what to segment, SAM returns the geometry.
- The Meta key lives only on the backend. The app never holds it. Re-analyzing a picture you already
  opened is served from the backend's cache, not paid for twice.

## Studying, not just exploring

Everything below is computed on the phone from the masks and boxes — no extra model calls, so it
works even when the network does not:

- **Map in words.** Three-finger hold reads the overview plus a three-band spoken map
  ("Top: cloud on the left, sun on the right. Middle: mountain…"), so the layout can be learned,
  not just visited.
- **What's around it.** A quick tap on a part also names its neighbours ("Around it: cloud to the
  left, mountain below"), which is how a mental picture gets its edges.
- **Guide me there.** Hold and ask *"Where is the sun?"* and guide mode points you as you drag:
  rest and it says the direction and whether you are close or far, and celebrates when your finger
  lands on the mask.
- **Practise missed.** The quiz remembers the questions you missed, skipped or had revealed, and
  the end of the quiz offers a second round with only those.
- **Study notes.** A plain-text screen (overview, map in words, every part with its size and
  neighbours) that a screen reader can read top to bottom — revision without re-analyzing.

## Gestures

Carried over from the earlier app, plus finger exploration:

| Where | Gesture | Does |
| --- | --- | --- |
| Centre | Touch or drag one finger | Explore: hear and feel the part under it |
| Centre | Move, then rest | Hear the part's description |
| Centre | Quick tap | Hear its name and description now, and what is around it |
| Centre | Hold still 0.5 s, speak, lift | Ask a question about the picture, or ask "Where is the …?" to be guided to it |
| Explore screen | Lesson / Quiz me buttons | Guided lesson, or a quiz: touch the part it names, answer questions out loud |
| Lesson / Quiz | Left-edge swipe, buttons below | Next / previous step or question; hold right edge to go back to exploring |
| Left edge | Tap / double tap | Stop and resume talking / repeat |
| Left edge | Swipe (finger down = next) | Step through the parts without dragging |
| Right edge | Hold, then drag up or down | Speech faster or slower |
| Right edge | Hold without dragging | Back |
| Anywhere | Three-finger tap / hold | Repeat last / hear the overview and the map in words |

## Architecture

```
lib/
  core/            speech, haptics, sound behind interfaces; theme; the animated braille logo
  features/touch/
    domain/        Region, Analysis, hit-testing, spatial words (map, neighbours)  (pure Dart)
    gestures/      the gesture engine: touches -> gestures (pure Dart, no clock, no timers)
    application/   TouchSession: gestures -> speech/touch/sound  (pure Dart) + Riverpod controller
    data/          the backend client
    presentation/  screens, the gesture surface, the picture painter
  features/learn/
    domain/        Lesson, Quiz, Grade                     (pure Dart)
    application/   LearnSession: lesson steps + quiz grading (pure Dart)
backend/           Node: Muse Spark + SAM 3.1 -> regions; Spark -> lesson, quiz, tutor chat
```

Every effect (voice, vibration, tones, microphone, network) sits behind an interface, so the whole
behaviour of the app is unit-tested without a phone. The Flutter layer only draws state and feeds in touches.

## Run it

Needs the [Flutter SDK](https://docs.flutter.dev/get-started/install), Node 20.17+, and a Meta Model API key from <https://dev.meta.ai/platform>.

```bash
# 1. Backend (holds your key)
cd backend && npm install && cp .env.example .env     # put your key in MODEL_API_KEY
npm run check:api                                      # one Muse Spark call and one SAM call: confirms the key works
npm start                                              # http://localhost:3000

# 2. App (new terminal, from the repo root)
tool/setup.sh                                          # generates android/ ios/ web/, adds permissions
flutter test
flutter run --dart-define=API_BASE=http://<your-computer's-ip>:3000
```

**Try the sample** works with no key: its outlines are hand-authored by `backend/scripts/make-sample.py`,
not model output, and the app says so out loud.

### iPhone

See [`docs/IPHONE.md`](docs/IPHONE.md). Short version: the web build runs in iPhone Safari from a link, with
speech and sound, but not vibration, because Safari has none. A native iPhone build has the haptics.

## Tests

```bash
flutter test            # gestures, hit-testing, the session, sound synthesis
cd backend && npm test  # the Meta pipeline, mask handling, the API
```

## Known limits

- One picture at a time; analysis takes roughly half a minute because every part is its own SAM request.
- SAM 3.1 matches one concept per request, so a vaguely phrased label can match nothing. The backend retries with simpler concepts; if it still finds nothing but Muse Spark gave a rough box, the part stays touchable as an approximate rectangle (the app says so), and many tiny matches in one photo (every tooth in a close-up) are merged into one region.
- Vibration is timed on Android. On iPhone it is a series of taps, and none at all in the browser.
- With TalkBack or VoiceOver on, the screen reader takes over one-finger touch, so use the buttons under the picture.

## Built with

Meta Model API (Muse Spark 1.3, SAM 3.1), Flutter, Riverpod, Node. The initial project scaffold was
written with help from Claude (Anthropic) as a coding assistant.

## License

MIT. See `LICENSE` and `NOTICE.md`.
