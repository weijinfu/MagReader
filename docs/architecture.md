# Architecture

MagReader is organized as a multi-platform, local-first reading application.

## Design Goals

- Run locally without accounts or cloud sync.
- Keep Web and iOS usable independently.
- Store user data in local SQLite.
- Fetch RSS and translation/dictionary data directly from client-side platform services.
- Keep translation, dictionary, RSS, and persistence logic behind narrow service boundaries.

## Web App

The Web app is a Next.js application.

Key directories:

- `app/`: App Router pages and API routes.
- `components/`: React UI.
- `lib/`: SQLite, RSS, translation, dictionary, and utility logic.
- `tests/`: Vitest unit and UI smoke tests.

Runtime shape:

```text
Browser UI
  -> Next.js API routes
    -> local SQLite
    -> RSS/translation/dictionary services
```

The Web app stores data in `data/magreader.db` unless `MAGREADER_DB` points elsewhere.

## iOS App

The iOS app is a native SwiftUI application.

Key directories:

- `ios/MagReader/MagReader/`: app source.
- `ios/MagReader/MagReaderTests/`: unit tests.
- `ios/MagReader/MagReaderUITests/`: UI smoke tests.

Runtime shape:

```text
SwiftUI
  -> service protocols
    -> local SQLite in app sandbox
    -> URLSession RSS/translation/dictionary requests
```

The iOS app does not use the Web app's Next.js API routes.

## Shared Product Concepts

The platforms share these concepts but not source code:

- `Feed`
- `Article`
- `SavedWord`
- `SavedSentence`
- `ReaderSettings`
- `LearningAnalysis`
- `WordMeaning`
- `Familiarity`

When changing product behavior, update both platform models when appropriate and record parity status in `docs/ios-web-feature-comparison.md`.

## Data Compatibility

Web and iOS schemas are intentionally similar, but there is no automatic migration or sync between them.

Future import/export work should be planned as explicit tooling rather than implicit DB sharing.

