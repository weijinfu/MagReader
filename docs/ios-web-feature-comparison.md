# iOS vs Web Feature Comparison

Last updated: 2026-06-06 22:10 CST

## Summary

The iOS native app and Web app now share the core MagReader workflow: RSS feeds, article reading, text highlight/translation, saved words/sentences, review, reader settings, Google/MyMemory translation providers, and on-demand dictionary meanings for words.

The iOS app remains local-native and stores data in the iOS sandbox SQLite database. The Web app remains local-first through the Next.js server and local SQLite database. They do not share databases.

## Feature Matrix

| Area | iOS Native | Web | Status |
| --- | --- | --- | --- |
| Local storage | App sandbox SQLite | Local `web/data/magreader.db` SQLite | Equivalent model, separate DBs |
| RSS/Atom feeds | Direct `URLSession` refresh | Server-side RSS refresh | Equivalent user workflow |
| Article list | Grouped by Feed, collapsible | Grouped by Feed, collapsible | Aligned |
| Reader | SwiftUI + `WKWebView` | React reader HTML view | Aligned core behavior |
| Word selection | Tap word to highlight, tap highlight to translate | Click word to highlight, click highlight to translate | Aligned |
| Sentence selection | Long press sentence to highlight, tap highlight to translate | Long press sentence to highlight, click highlight to translate | Aligned |
| Blank-area cancel | Clears active highlight | Global outside click clears active highlight | Aligned |
| Selection actions | Translate, Speak, Copy, Save | Translate, Speak, Copy, Save, Details/More | Aligned; Web keeps desktop Details/More |
| Initial word translation | Fast provider translation only | Fast provider translation only | Aligned |
| More word meanings | `Show More Meanings` queries dictionary on demand | `Show More Meanings` queries dictionary on demand | Aligned |
| Dictionary source | `dictionaryapi.dev` | `dictionaryapi.dev` | Aligned |
| Dictionary display | Chinese definition first, English auxiliary | Chinese definition first, English auxiliary | Aligned |
| Dictionary count | No fixed definition cap | No fixed definition cap | Aligned |
| Save word meanings | Persists `meanings_json` | Persists `meanings_json` | Aligned |
| Saved word detail | Can load missing meanings without incrementing count | Saved card details can load missing meanings without incrementing count | Aligned |
| Review Speak | Explicit Speak button only | Explicit Speak button only | Aligned |
| Review mastered | Confirm and delete in iOS | Confirm and delete in Web Review | Aligned |
| Settings providers | Google, MyMemory | Google, MyMemory | Aligned |
| Mock provider | Test/fixture only | Test/local helper only, not Settings | Aligned |
| Reader background | Light reader background options | Theme/font/width controls, no iOS-style background picker | Partial |
| Export | Deferred in iOS | Web supports CSV export | Web superset |

## Web Changes Implemented For iOS Parity

- Added `WordMeaning` and `wordMeanings` types.
- Added `saved_words.meanings_json` migration and mapping.
- Added saved-word meanings persistence and update without incrementing save count.
- Added `dictionaryapi.dev` lookup service.
- Changed Web word analysis to fast provider translation first.
- Added on-demand dictionary meanings through `/api/ai` with `mode: "meanings"`.
- Added dictionary UI in learning panels and saved/review cards.
- Removed Mock from user-visible Web Settings and restricted provider choices to Google/MyMemory.
- Added Feed-grouped, collapsible article list with Expand All / Collapse All.
- Added Copy actions to Web selection toolbar, learning panel, and mobile sheet.
- Added Review mastered confirmation that deletes the local saved item after confirmation.
- Changed Web reader selection toward the iOS two-step model:
  - Click word: highlight only.
  - Click active highlight: open learning sheet/panel and translate.
  - Long press sentence: highlight sentence only.
  - Click active sentence highlight: open learning sheet/panel and translate.

## Remaining Differences

- Web keeps desktop-specific affordances such as sidebar collapse, article-list hide/show, CSV export, and content-width settings.
- iOS keeps native-specific affordances such as app icon/home screen behavior, AVSpeech audio session handling, and `WKWebView` gesture tuning.

## Verification

- `cd web && npm run verify`: required after Web changes.
- Xcode Product > Build / Product > Test: required after iOS changes.
