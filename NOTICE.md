# Third-party material

## Fonts (in `assets/fonts/`, licence texts beside them)

| Font | Used for | By | Licence |
| --- | --- | --- | --- |
| Metropolis | Wordmark and headings | Chris Simpson ([source](https://github.com/dw5/Metropolis), via [Fontsource](https://fontsource.org/fonts/metropolis)) | The Unlicense (public domain). See `assets/fonts/UNLICENSE-Metropolis.txt` |
| Atkinson Hyperlegible Next | Body text, made for low vision | Braille Institute and Applied Design Works | SIL Open Font License 1.1. See `assets/fonts/OFL-Atkinson-Hyperlegible-Next.txt` |

Both were first used in the author's earlier app, Resonant, and are carried over unchanged.

## Meta Model API

Muse Spark 1.3 and SAM 3.1 are used through the Meta Model API under Meta's terms: <https://dev.meta.ai>.
Mask parsing uses `@meta-sam/parser` (see `backend/package.json`).
The one frame of SAM output used as a test fixture (`backend/test/helpers.js`) is copied from Meta's SAM documentation.

## Other libraries

Flutter and the packages in `pubspec.yaml`, and the Node packages in `backend/package.json`, keep their own licences.
