# Web vs iOS vs macOS Feature Comparison

Last updated: 2026-06-10 00:31 CST

## Summary

The Web, iOS, and macOS apps now share the core MagReader workflow: RSS feeds, article reading, text highlight/translation, saved words/sentences, review, reader settings, Google/MyMemory translation providers, and on-demand dictionary meanings for words.

Each platform remains local-first with its own SQLite database. The native Apple apps share Swift business logic through `shared/MagReaderCore`; the Web app mirrors the same product behavior in TypeScript.

## Feature Matrix

| Area | Web | iOS Native | macOS Native | Status |
| --- | --- | --- | --- | --- |
| Local storage | `web/data/magreader.db` SQLite | App sandbox SQLite | `Application Support/MagReaderMac` SQLite | Equivalent model, separate DBs |
| RSS/Atom feeds | Server-side refresh | Direct `URLSession` refresh | Direct `URLSession` refresh | Aligned user workflow |
| Article list | Grouped by Feed, collapsible | Grouped by Feed, collapsible | Grouped by Feed, collapsible | Aligned |
| Reader | React reader HTML view | SwiftUI + `WKWebView` | SwiftUI + `WKWebView` | Aligned core behavior |
| Word selection | Click word, click highlight to translate | Tap word, tap highlight to translate | Click word, click highlight to translate | Aligned |
| Sentence selection | Long press sentence, click highlight to translate | Long press sentence, tap highlight to translate | Double-click sentence, click highlight to translate | Platform-native variants |
| Blank-area cancel | Clears active highlight | Clears active highlight | Clears active highlight | Aligned |
| Selection actions | Translate, Speak, Copy, Save, Details/More | Translate, Speak, Copy, Save | Translate, Speak, Copy, Save, More | Aligned |
| Initial word translation | Fast provider translation only | Fast provider translation only | Fast provider translation only | Aligned |
| More word meanings | Dictionary on demand | Dictionary on demand | Dictionary on demand | Aligned |
| Dictionary source | `dictionaryapi.dev` | `dictionaryapi.dev` | `dictionaryapi.dev` | Aligned |
| Dictionary display | Chinese definition first, English auxiliary | Chinese definition first, English auxiliary | Chinese definition first, English auxiliary | Aligned |
| Dictionary count | No fixed definition cap | No fixed definition cap | No fixed definition cap | Aligned |
| Save word meanings | Persists `meanings_json` | Persists `meanings_json` | Persists `meanings_json` | Aligned |
| Saved word detail | Can load missing meanings without incrementing count | Can load missing meanings without incrementing count | Shows saved meanings and can save latest meanings | Mostly aligned |
| Review Speak | Explicit Speak button only | Explicit Speak button only | Explicit Speak button only | Aligned |
| Review mastered | Confirm and delete | Confirm and delete | Confirm and delete | Aligned |
| Settings providers | Google, MyMemory | Google, MyMemory | Google, MyMemory | Aligned |
| Mock provider | Test/local helper only | Test/fixture only | Test/fixture only | Aligned |
| Reader background | Theme/font/width controls | Light reader background options | Light reader background options | Native apps aligned |
| Export | CSV/JSON export | Deferred | CSV/JSON save panel | Web/macOS superset |

## Shared Apple Core

The iOS and macOS apps share pure Swift code for models, SQLite migrations, RSS parsing, feed refresh, translation providers, dictionary lookup, analysis helpers, and export.

## Remaining Differences

- Web keeps desktop-specific affordances such as sidebar collapse, article-list hide/show, CSV export, and content-width settings.
- iOS keeps native-specific affordances such as app icon/home screen behavior, AVSpeech audio session handling, and `WKWebView` gesture tuning.
- macOS keeps desktop-specific affordances such as menu commands, toolbar actions, `NSSavePanel` export, and a right-side learning inspector.

## Verification

- `cd web && npm run verify`: required after Web changes.
- Xcode Product > Build / Product > Test: required after iOS changes.
- Xcode Product > Build for `macos/MagReaderMac.xcodeproj`: required after macOS changes.
