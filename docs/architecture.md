# Architecture

MagReader is organized as a multi-platform, local-first reading application.

## Design Goals

- Run locally without accounts or cloud sync.
- Keep Web, iOS, and macOS usable independently.
- Store user data in local SQLite.
- Fetch RSS and translation/dictionary data directly from client-side platform services.
- Keep translation, dictionary, RSS, and persistence logic behind narrow service boundaries.

## Web App

The Web app is a Next.js application.

Key directories:

- `web/app/`: App Router pages and API routes.
- `web/components/`: React UI.
- `web/lib/`: SQLite, RSS, translation, dictionary, and utility logic.
- `web/tests/`: Vitest unit and UI smoke tests.

Runtime shape:

```text
Browser UI
  -> Next.js API routes
    -> local SQLite
    -> RSS/translation/dictionary services
```

The Web app stores data in `web/data/magreader.db` unless `MAGREADER_DB` points elsewhere.

## Shared Apple Core

Apple native apps share pure Swift business logic through `shared/MagReaderCore`.

Key responsibilities:

- Product models: `Feed`, `Article`, `SavedWord`, `SavedSentence`, `ReaderSettings`, `LearningAnalysis`, `WordMeaning`, and related enums.
- SQLite schema and migrations, including `saved_words.meanings_json`.
- RSS/Atom parsing and feed refresh behavior.
- Google/MyMemory translation providers.
- `dictionaryapi.dev` lookup and on-demand dictionary meanings.
- HTML cleanup, word/sentence helpers, difficulty helpers, and CSV/JSON export.

Platform-specific bridges stay outside Core:

- Reader WebView wrappers.
- Speech service implementations.
- App container paths and OS UI.

## iOS App

The iOS app is a native SwiftUI application.

Key directories:

- `ios/MagReader/`: SwiftUI app, reader bridge, assets, and platform wiring.
- `ios/MagReaderTests/`: unit tests.
- `ios/MagReaderUITests/`: UI smoke tests.

Runtime shape:

```text
SwiftUI
  -> shared MagReaderCore services
    -> local SQLite in app sandbox
    -> URLSession RSS/translation/dictionary requests
```

The iOS app does not use the Web app's Next.js API routes.

## macOS App

The macOS app is a native SwiftUI application.

Key directories:

- `macos/MagReaderMac/`: SwiftUI app, AppKit/WebKit bridges, assets, and platform wiring.
- `macos/MagReaderMacTests/`: reserved for macOS-specific tests.
- `macos/MagReaderMacUITests/`: reserved for UI smoke tests.

Runtime shape:

```text
SwiftUI NavigationSplitView
  -> shared MagReaderCore services
    -> local SQLite in Application Support/MagReaderMac
    -> URLSession RSS/translation/dictionary requests
```

The macOS app does not use Catalyst, npm, Next.js, or another platform database.

## Shared Product Concepts

The Web platform mirrors the same product concepts in TypeScript. iOS and macOS share Swift source code for the core business layer:

- `Feed`
- `Article`
- `SavedWord`
- `SavedSentence`
- `ReaderSettings`
- `LearningAnalysis`
- `WordMeaning`
- `Familiarity`

When changing product behavior, update Web TypeScript and shared Apple Core when appropriate, then record parity status in `docs/ios-web-feature-comparison.md`.

## Data Compatibility

Web, iOS, and macOS schemas are intentionally similar, but there is no automatic migration or sync between them.

Future import/export work should be planned as explicit tooling rather than implicit DB sharing.
