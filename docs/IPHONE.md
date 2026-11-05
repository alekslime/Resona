# Getting Resonant onto an iPhone (most judges have one)

Be realistic about what each route needs.

| Route | What the judge needs | What you need | Haptics | Sound and speech |
| --- | --- | --- | --- | --- |
| **Web link** (recommended for judging) | An iPhone and Safari. Nothing to install | The backend deployed with HTTPS, serving the web build | **None.** iPhone Safari has no vibration API | Yes: voice, tones, stereo |
| Native iPhone app via TestFlight | The TestFlight app and your invite | A Mac with Xcode and a paid Apple Developer account; Apple reviews external testers' builds | Yes: Taptic taps | Yes |
| Android APK | An Android phone | `flutter build apk` | Full timed patterns | Yes |

## Why the web link comes first

Judges will not install an app from a stranger in the middle of scoring. A link opens in one tap. The
cost is vibration, which is why every chat state also has a sound: listening, thinking and speaking
all sound different, so an iPhone user can follow the conversation with their eyes closed and
headphones on. Tell judges to use headphones, and say so at the start of the video.

## Build and serve the web version

```bash
flutter build web --release                 # from the repo root: writes build/web
cd backend && npm start                      # serves the API and build/web from one origin
```

Deploy `backend/` to any Node host with `MODEL_API_KEY` set as a secret, and make sure the host serves
`../build/web` (copy `build/web` next to it if your host only deploys the `backend` folder, and change
`webDir` in `backend/server/index.js`). Open the URL on an actual iPhone before you submit.

Known web limits: voice questions (hold to ask) depend on the browser's speech recognition and may
not work in Safari, in which case the app says the microphone is unavailable. Check on a real iPhone, and
have the question flow shown in the video from Android or Chrome if it fails there.

## Native iPhone build (only if you have a Mac)

```bash
tool/setup.sh                                # once
open ios/Runner.xcworkspace                  # set a signing team in Xcode
flutter run --release --dart-define=API_BASE=https://your-backend.example
```

On iPhone, vibration is a series of taps through the Taptic Engine, not timed buzzes, so patterns feel
different from Android. That is a platform limit, not a bug. TestFlight needs a paid Apple Developer
account; if you do not have one, the web link is your iPhone route.
