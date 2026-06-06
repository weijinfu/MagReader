# MagReader iOS Native App Plan

## Current Goal

Implement a local native iOS version of MagReader under `ios/MagReader`.

The iOS app must run independently on iPhone/iPad without starting the existing Next.js/Node service. It should persist all user data in the app sandbox, fetch RSS feeds directly when online, support translation/learning analysis, and cover the core reading and review workflow.

## Scope

- Build a native SwiftUI iOS app from scratch.
- Store all iOS app data locally in SQLite.
- Do not migrate or share the existing web `data/magreader.db`.
- Do not depend on the local Next.js API server.
- First version covers:
  - Feed management.
  - RSS/Atom refresh.
  - Article list and article reader.
  - Text selection for words, phrases, and sentences.
  - Translation and learning analysis.
  - Save word and save sentence flows.
  - Saved item management.
  - Review queue.
  - Reader settings.
- First version does not cover:
  - CSV/JSON export.
  - Cloud sync.
  - User accounts.
  - App Store distribution and notarization.
  - Importing the existing web SQLite database.
  - Full parity with every web translation provider.

## Implementation Plan

### Project Structure

- Create `ios/MagReader` as a SwiftUI iOS app.
- Minimum target: iOS 17.
- Use SwiftUI state, `ObservableObject/@Published`, async/await, `TabView`, and one `NavigationStack` per major tab.
- Main tabs:
  - `Articles`
  - `Feeds`
  - `Saved`
  - `Review`
  - `Settings`
- App-level dependencies:
  - `DatabaseClient`
  - `FeedRefreshService`
  - `TranslationService`
  - `SpeechService`
  - `SettingsStore`
- Prefer environment injection for app-wide services and initializer injection for feature-local dependencies.

### Models And Types

Create Swift model types aligned with the existing web app surface:

- `Feed`
- `Article`
- `SavedWord`
- `SavedSentence`
- `ReaderSettings`
- `LearningAnalysis`
- `Familiarity`
- `TranslationProvider`

Required enum values:

- `Familiarity`: `new`, `learning`, `familiar`, `mastered`.
- `TranslationProvider`: `google`, `mymemory` for v1.
- `Article.status`: `unread`, `read`, `archived`.

### Data Layer

- Use local SQLite in the app sandbox.
- Prefer GRDB.swift if SPM dependency resolution is available.
- If dependency resolution is blocked, use a thin local sqlite3 wrapper instead of blocking implementation.
- Create migrations for:
  - `feeds`
  - `articles`
  - `saved_words`
  - `saved_sentences`
  - `settings`
  - `ingestion_logs`
- Preserve web app persistence semantics:
  - Feeds dedupe by `url`.
  - Articles dedupe by `url`.
  - Visible article lists exclude archived articles.
  - Saved words normalize to lowercase `word`.
  - Saving an existing word increments `count` and updates translation/explanation.
  - Saved sentences dedupe by exact `text`.
  - Review state updates write `familiarity` and `updatedAt`.

### RSS And Article Ingestion

- Implement RSS/Atom fetching with `URLSession`.
- Use a Swift RSS/Atom parser package if available.
- If unavailable, implement a minimal `XMLParser`-based parser that supports:
  - Feed title.
  - Item title.
  - Link.
  - GUID or Atom ID.
  - Published date.
  - Summary.
  - Content/content encoded.
- Refresh only enabled feeds.
- For each refresh:
  - Upsert current feed items into `articles`.
  - Track current URLs.
  - Archive previously visible articles for that feed when they are no longer present in the feed snapshot.
  - Record success or failure in `ingestion_logs`.
  - Store feed `lastFetchedAt` and `lastError`.
- Prefer feed-provided HTML/content.
- If feed content is short or missing, attempt a best-effort article HTML fetch.
- On timeout, 403, blocked extraction, malformed HTML, or parse failure, fall back to RSS summary/title.
- Sanitize article HTML before display by removing scripts, styles, event-handler attributes, and obviously unsafe markup.

### Reader And Selection

- Implement article detail as a SwiftUI shell with a `WKWebView` reader.
- The reader must support:
  - Clean article HTML rendering.
  - Light/dark theme.
  - Font family.
  - Font size.
  - Line height.
  - Paragraph gap.
  - Text selection.
- Bridge selected text from `WKWebView` back into SwiftUI.
- Show a native bottom sheet after selection with:
  - `Translate`
  - `Speak`
  - `Save`
  - `Details`
- Classify selected text:
  - A single likely English token is a word.
  - Any other non-empty selection is a sentence/phrase and saves as sentence.
- Keep selection and analysis visible until the user changes selection, closes the sheet, or navigates away.

### Translation And Learning Analysis

- Define `TranslationService` protocol.
- Implement v1 providers:
  - `GoogleTranslationService`
  - `MyMemoryTranslationService`
- Settings should expose only `Google` and `MyMemory` in v1.
- Keep a fixture translation service only for tests and UI seed data.
- Single-word analysis should first use the selected translation provider for a fast primary Chinese translation.
- Structured dictionary meanings should load only when the user taps `Show More Meanings`.
- On-demand dictionary lookup uses `dictionaryapi.dev`, then translates every returned English definition through the selected translation provider in batches.
- Recreate the web app's local analysis behavior:
  - Translation.
  - Provider label.
  - Word vs sentence kind.
  - Explanation.
  - Phrase hints.
  - Structure splitting.
  - Difficulty level and score.
- Keep the analysis contract stable so Baidu, Youdao, Microsoft, OpenAI, or a paid dictionary API can be added later without changing views.

### Speech

- Implement `SpeechService` with `AVSpeechSynthesizer`.
- Support speaking:
  - Article title.
  - Selected text.
  - Saved words.
  - Saved sentences.
- Respect `ReaderSettings.speechRate`.

### Saved And Review

- Saved Words:
  - List saved words.
  - Show translation, explanation, source sentence, source article, count, and familiarity.
  - Update familiarity.
  - Delete saved word.
- Saved Sentences:
  - List saved sentences.
  - Show translation, explanation, source article, and familiarity.
  - Update familiarity.
  - Delete saved sentence.
- Review:
  - Show non-mastered saved words and sentences by default.
  - Support revealing/hiding answers.
  - Support status progression.
  - Support speaking items.

### Settings

- Persist settings locally.
- Include:
  - Theme.
  - Translation provider.
  - Font family.
  - Font size.
  - Line height.
  - Paragraph gap.
  - Speech rate.
- Apply reader settings immediately to the current reader view.

## Feature Checklist

- [x] Create iOS project under `ios/MagReader`.
- [x] Add Swift model types.
- [x] Add service protocols.
- [x] Add app shell with tabs and navigation.
- [x] Add local SQLite database.
- [x] Add migrations.
- [x] Add feed CRUD.
- [x] Add RSS/Atom parser.
- [x] Add feed refresh pipeline.
- [x] Add article list.
- [x] Add article detail reader.
- [x] Add `WKWebView` selection bridge.
- [x] Add translation service.
- [x] Add learning analysis.
- [x] Add speech service.
- [x] Add save word flow.
- [x] Add save sentence flow.
- [x] Add Saved Words view.
- [x] Add Saved Sentences view.
- [x] Add Review view.
- [x] Add Settings view.
- [x] Add real app icon asset.
- [x] Add unit tests.
- [x] Add UI smoke tests.
- [x] Verify simulator build.
- [x] Verify test build.

## Test Plan

### Unit Tests

- Database migration creates all required tables.
- Feed URL dedupe works.
- Article URL dedupe works.
- Archived articles are hidden from visible article queries.
- Saved word normalization works.
- Re-saving a word increments `count`.
- Saved sentence exact-text dedupe works.
- Familiarity updates work for words and sentences.
- Delete works for words and sentences.
- Fixture translation produces stable test-only `LearningAnalysis`.
- Dictionary fixture parsing returns multiple `WordMeaning` entries.
- Saved words persist and reload multiple dictionary meanings.
- Word/sentence detection handles plain, apostrophe, and hyphenated English words.
- RSS fixture parsing covers RSS, Atom, missing content, and duplicate article URL cases.

### UI Tests

- App launches into an empty articles state.
- User can add a feed.
- Refresh failure displays a clear error.
- Article list opens article detail.
- Reader settings update the current reader.
- Selecting text opens the learning bottom sheet.
- Translate displays analysis.
- Save word creates a saved word visible in Saved and Review.
- Save sentence creates a saved sentence visible in Saved and Review.
- Review item can reveal answer and update familiarity.

### Verification Commands

- Use Xcode 26.3 and Swift 6.2.4.
- Build for iOS simulator.
- Run iOS unit tests.
- Run iOS UI smoke tests.
- Manually verify one real RSS feed, one Google/MyMemory translation request, and one `dictionaryapi.dev` word lookup when network access is available.

## Progress Notes

- 2026-06-03 20:37:36 CST: Replaced `plan.md` with a clean iOS-native implementation plan. This file is now the source of truth for future iOS work, progress notes, verification results, and next goals.
- 2026-06-03 20:57:23 CST: Implemented the first native iOS version under `ios/MagReader`. Added a SwiftUI app target, app shell tabs, aligned model types, sqlite3 persistence, RSS/Atom parsing and refresh, WKWebView article reader with text-selection bridge, Mock/MyMemory translation analysis, AVSpeechSynthesizer playback, Saved/Review/Settings screens, unit tests, and UI smoke tests. Switched from Swift macro-based Observation to `ObservableObject/@Published` because the current sandbox could not run Xcode macro plugin server reliably.
- 2026-06-03 21:00:55 CST: Replaced the review familiarity segmented picker with explicit buttons to avoid a Swift 6 compiler IRGen crash caused by binding a main-actor closure through `Picker`. Rebuilt successfully afterward.
- 2026-06-03 21:23:47 CST: Added a generated MagReader iOS app icon to `Assets.xcassets/AppIcon.appiconset`. The icon uses a book/magazine page, speech-bubble shape, bookmark accent, navy background, warm paper, teal, and amber highlights. Source asset is a 1024x1024 PNG without alpha.
- 2026-06-03 21:26:19 CST: Updated the Articles tab to group visible articles by Feed. Each feed now renders as a section header with article count, and article rows no longer repeat the feed name inside a feed section.
- 2026-06-03 21:29:04 CST: Optimized Articles feed grouping with collapsible `DisclosureGroup` sections. Feed groups are expanded by default, can be collapsed individually, and the toolbar now includes Expand All and Collapse All group actions.
- 2026-06-03 21:33:52 CST: Replaced the iOS app icon with a simpler light-background version. The updated icon removes article-line details and keeps only the open book/speech-bubble silhouette, teal backing shape, and amber bookmark.
- 2026-06-03 22:00:53 CST: Stabilized and expanded iOS verification. Fixed the WKWebView selection bridge JavaScript timer bug, added UI-test seeded in-memory app mode, expanded unit coverage to settings persistence, HTML sanitization, feed deletion cleanup, date/difficulty helpers, and expanded UI smoke coverage across Articles, article detail, Feeds, Saved, Review, and Settings.
- 2026-06-04 08:27:50 CST: Fixed iOS reader word and paragraph selection interaction. The reader supports tap-to-select-word and long-press-to-select-paragraph through a native gesture bridge into `WKWebView`, with JavaScript selection/highlighting and a Swift fallback callback from `evaluateJavaScript`. This fixed the case where text highlighted but the learning sheet did not open.
- 2026-06-04 20:03:00 CST: Tightened iOS reader selection to reduce accidental triggers. Single tap no longer selects text. Double tap selects a word and opens the learning sheet. Long press is handled inside the WebView with browser touch coordinates for paragraph/block selection. Native selection fallback now ignores short fragments and single words, so metadata like `B2` or accidental one-word native selections do not auto-open translation. The selection sheet now starts translation automatically when it appears, and SwiftUI debounces repeated selection callbacks while a sheet is already open.
- 2026-06-04 21:59:00 CST: Reworked iOS reader selection into a two-stage highlight flow. A single tap highlights the tapped word only; tapping the highlighted word again opens the learning sheet and starts translation. Long press now uses custom WebView sentence detection, disables native text selection/callout, and highlights the whole sentence without opening the system selection UI; tapping the highlighted sentence opens translation. The learning sheet action area now includes Copy and uses a two-column adaptive grid to avoid cramped button labels.
- 2026-06-04 22:15:00 CST: Refined the iOS reader selection flow and learning sheet. The sheet now opens at a smaller height with a compact selected-text preview and small two-column action buttons. Sentence detection now computes the sentence range from the containing text block rather than the tapped text node, which reduces partial-sentence highlights when paragraphs include inline nodes. Clicking outside the active highlight now clears the highlight instead of committing translation.
- 2026-06-04 22:25:00 CST: Adjusted active-highlight behavior in the iOS reader. When a word or sentence is already highlighted, tapping another word now immediately switches the highlight to that word instead of requiring a separate clear action. Tapping a blank/non-word area still clears the active highlight.
- 2026-06-06 10:57:34 CST: Implemented the iOS dictionary-style word translation update. The app now removes user-visible Mock translation, adds Google as the default provider, keeps MyMemory, uses `dictionaryapi.dev` for structured word meanings, translates dictionary definitions into Chinese with the selected provider, persists saved-word meanings in SQLite `meanings_json`, and keeps a fixture translation service only for tests/UI seed data.
- 2026-06-06 11:54:28 CST: Fixed the next iOS usability batch. Settings consumers now explicitly observe `SettingsStore`, so translation provider, speech rate, typography, and reader background changes apply without restarting. Word dictionary analysis now avoids the extra primary word-translation request when dictionary meanings exist, caps dictionary meanings to five, batches Google definition translation, and lowers translation/dictionary timeouts. Speech now activates an iOS `.playback`/`.spokenAudio` audio session before speaking. Saved words/sentences now open detail sheets from the Saved list, saved word rows no longer show the confusing `x<count>` badge, Review `mastered` now asks for confirmation and deletes the saved item on confirmation, and Settings now includes reader background choices.
- 2026-06-06 13:00:40 CST: Refined dictionary and Review interaction. Word analysis now translates only the first dictionary definition by default, leaving additional definitions un-translated until the user expands the UI. Dictionary sections in the selection sheet, Saved word detail, and Review show one meaning first and provide a `Show More Meanings` button to reveal the rest. Review `Reveal` and `Speak` now use explicit bordered button styles so tapping the review text/row does not route to Speak.
- 2026-06-06 15:26:19 CST: Reworked word translation latency again. Single-word analysis now returns immediately from the selected fast translation provider and does not call `dictionaryapi.dev` during the initial sheet load. `Show More Meanings` now performs the dictionary lookup on demand, translates all returned definitions into Chinese in batches, and removes the previous five-definition cap. Saved word detail can now load missing dictionary meanings on demand and persist them through `updateSavedWordMeanings` without incrementing the saved word `count`. Review Speak remains explicit-button only.
- 2026-06-06 15:34:00 CST: Adjusted on-demand dictionary display. After `Show More Meanings` finishes loading in the selection sheet or Saved word detail, all loaded meanings are shown immediately; the user no longer needs a second expand tap. Existing saved words that already have meanings still default to a compact preview in detail/review contexts.
- 2026-06-06 21:47:00 CST: Added Web/iOS parity documentation and synced the Web app toward current iOS behavior. Added `docs/ios-web-feature-comparison.md`, Web `WordMeaning`/`meanings_json` support, on-demand `dictionaryapi.dev` meanings, fast-first word translation, Feed-grouped collapsible article list, two-step word/sentence highlight-to-translate flow, Copy actions, Review mastered confirm-and-delete, Google/MyMemory-only Settings, and Saved/Review dictionary meaning display/update.
- 2026-06-06 21:56:00 CST: Repackaged MagReader as an open-source multi-platform project. Rewrote `README.md`, added MIT `LICENSE`, contribution/security/code-of-conduct docs, changelog, `.env.example`, platform/development/architecture docs, GitHub CI, issue templates, PR template, and package metadata/scripts for Web and iOS verification.

## Next Steps

1. Manually verify one fresh real RSS feed refresh with network access.
2. Manually verify fast single-word translation latency and on-demand dictionary quality on device/network conditions.
3. Manually verify Speak audio on a physical device or local Simulator with audio output enabled.
4. Manually verify the new app icon on the iOS Home Screen after installing the app on Simulator or device.
5. Add a dedicated UI test for the two-stage reader selection flow if a stable WKWebView coordinate strategy is available.
6. Add polish for empty/error states after real feed refresh testing.
7. Add optional import/export planning only after the native core flow is validated.

## Verification Status

- 2026-06-03 20:37:36 CST: Documentation-only rewrite. No code build or test suite was run.
- 2026-06-03 20:52:49 CST: `xcodebuild -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build` passed. Xcode printed CoreSimulator service warnings in the sandbox, but the app target built successfully.
- 2026-06-03 20:53:01 CST: `xcodebuild -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build-for-testing` passed for app, unit test, and UI test targets.
- 2026-06-03 20:57:23 CST: Full `xcodebuild test` was attempted on iPhone 17 Simulator with elevated simulator access. Build and install progressed, but simulator launch failed with `NSMachErrorDomain Code=-308 "(ipc/mig) server died"` for both the app and UI test runner, so tests did not execute in this environment.
- 2026-06-03 21:00:26 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build` passed after the familiarity picker fix.
- 2026-06-03 21:00:55 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build-for-testing` passed after the familiarity picker fix. Xcode still prints CoreSimulator service warnings in the sandbox, but compilation and test bundle build completed.
- 2026-06-03 21:23:47 CST: Verified the app icon asset with `sips -g pixelWidth -g pixelHeight -g hasAlpha ios/MagReader/MagReader/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`; result is 1024x1024 with no alpha. `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build` passed with elevated CoreSimulator access after a sandboxed run failed to access simulator runtimes.
- 2026-06-03 21:26:19 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build` passed after the Articles feed grouping change.
- 2026-06-03 21:29:04 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build` passed after adding collapsible Articles feed groups.
- 2026-06-03 21:33:52 CST: Verified the simplified light app icon with `sips -g pixelWidth -g pixelHeight -g hasAlpha ios/MagReader/MagReader/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`; result is 1024x1024 with no alpha. A sandboxed `xcodebuild` run failed to access simulator runtimes, then the same build passed with elevated CoreSimulator access.
- 2026-06-03 21:51:21 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,id=04E57135-215F-4833-8C05-8A9C933D7E04' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderTests test` passed 10 unit tests.
- 2026-06-03 21:57:23 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,id=04E57135-215F-4833-8C05-8A9C933D7E04' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderUITests test` passed 5 UI smoke tests. Xcode printed one non-fatal CoreSimulator clone launch warning, but the test command exited successfully.
- 2026-06-03 22:00:53 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,id=04E57135-215F-4833-8C05-8A9C933D7E04' -derivedDataPath ios/MagReader/DerivedData test` passed the full scheme test suite: 10 unit tests and 5 UI tests.
- 2026-06-03 22:01:49 CST: Build iOS Apps `build_run_sim` launched the app successfully on iPhone 17 Simulator. Screenshot captured at `/var/folders/v6/3rfh7g614psg4yh7n5plbkz80000gn/T/screenshot_optimized_c0c86e04-36cc-4860-9a87-ee5165bc303c.jpg`, showing the Articles tab with collapsible ProPublica feed grouping.
- 2026-06-03 22:03:00 CST: Build iOS Apps runtime UI snapshot confirmed Articles, Groups, Refresh, and all five tabs are reachable. Tapped a real ProPublica article and verified article detail renders in `WKWebView`; screenshot captured at `/var/folders/v6/3rfh7g614psg4yh7n5plbkz80000gn/T/screenshot_optimized_96d5a485-3924-4a00-b3e6-c71ae37d5548.jpg`.
- 2026-06-04 08:20:05 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,id=04E57135-215F-4833-8C05-8A9C933D7E04' -derivedDataPath ios/MagReader/DerivedData test` passed the full scheme suite after the first reader selection rewrite: 10 unit tests and 5 UI tests.
- 2026-06-04 08:27:50 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,id=04E57135-215F-4833-8C05-8A9C933D7E04' -derivedDataPath ios/MagReader/DerivedData test` passed the full scheme suite after adding native gesture fallback callbacks: 10 unit tests and 5 UI tests.
- 2026-06-04 08:29:00 CST: Build iOS Apps + Computer Use interaction verification passed on iPhone 17 Simulator. A real click inside `WKWebView` selected the word `to` and opened the `Word` sheet with Translate/Speak/Save actions. A long press inside a paragraph selected the full paragraph and opened the learning sheet with the complete paragraph text; screenshot captured at `/var/folders/v6/3rfh7g614psg4yh7n5plbkz80000gn/T/screenshot_optimized_6ffa91fc-208c-43e4-a8fc-b2a663c00327.jpg`.
- 2026-06-04 19:40:38 CST: Build iOS Apps `build_run_sim` and shell `xcodebuild build` passed after tightening selection interactions.
- 2026-06-04 19:41:37 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 10 unit tests.
- 2026-06-04 19:42:59 CST: Build iOS Apps full UI test target timed out at the tool 120 second limit during `test-without-building`, after `build-for-testing` succeeded. The UI tests were then run individually to avoid the tool timeout.
- 2026-06-04 20:02:02 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 10 unit tests after the final selection changes.
- 2026-06-04 20:01:00 CST: Build iOS Apps individual UI smoke tests passed 5/5: launch articles state/list, article list opens detail, Saved/Review tabs show seeded items, Settings tab reachable, Feeds tab shows seeded feeds.
- 2026-06-04 20:02:30 CST: Build iOS Apps + Computer Use interaction verification passed on iPhone 17 Simulator after the final selection changes. Single tap in article text did not open a sheet. Double tap on `taken` opened the `Word` sheet and auto-started MyMemory translation, then displayed translation `采取的`. Long press on a non-text/image area no longer opened stale `B2` or old selection text.
- 2026-06-04 21:52:30 CST: Build iOS Apps `build_run_sim` passed after the two-stage reader selection rewrite and Copy button addition.
- 2026-06-04 21:54:33 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 10 unit tests.
- 2026-06-04 21:58:45 CST: Build iOS Apps UI smoke for `testArticleListOpensArticleDetail` passed according to the xcresult/build log. The tool call itself hit the 120 second response timeout after the test had completed successfully.
- 2026-06-04 21:56:30 CST: Build iOS Apps + Computer Use interaction verification passed on iPhone 17 Simulator for the word flow. First tap on `taken` highlighted the word without opening a sheet. Second tap on the highlighted word opened the `Word` sheet, auto-started analysis, and showed the Copy button. A long press on the image/non-text center did not open native selection or a stale learning sheet. Precise coordinate validation for long-pressing body text is still best done manually on device/Simulator because current automation exposes the `WKWebView` only as one scroll-view element.
- 2026-06-04 22:12:58 CST: Build iOS Apps `build_run_sim` passed after the sheet and selection refinement.
- 2026-06-04 22:13:30 CST: Build iOS Apps + Computer Use interaction verification passed on iPhone 17 Simulator. First tap on `taken` highlighted the word; tapping the image/outside area cleared the highlight and did not open translation; tapping `taken` again then tapping the highlight opened the smaller `Word` sheet and auto-started analysis. Long press on non-text/image center did not show native text selection or a stale sheet.
- 2026-06-04 22:15:25 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 10 unit tests.
- 2026-06-04 22:23:00 CST: Build iOS Apps `build_run_sim` passed after active-highlight switching changes.
- 2026-06-04 22:23:40 CST: Build iOS Apps + Computer Use interaction verification passed on iPhone 17 Simulator. Tapping `taken` highlighted the word; tapping `over` while `taken` was highlighted directly switched the highlight to `over`; tapping a blank area cleared the highlight.
- 2026-06-04 22:25:42 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 10 unit tests.
- 2026-06-06 10:50:51 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build-for-testing` passed outside the sandbox after the sandboxed run failed to access CoreSimulator runtimes for asset catalog compilation.
- 2026-06-06 10:53:18 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderTests test` passed 12 unit tests, covering provider fallback, Google fixture parsing, dictionary fixture parsing, saved-word meanings persistence, and existing RSS/reader helpers.
- 2026-06-06 10:57:07 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderUITests test` passed 5 UI smoke tests.
- 2026-06-06 11:33:17 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build-for-testing` passed outside the sandbox after the seven-fix usability batch.
- 2026-06-06 11:38:51 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderTests test` passed 12 unit tests, including reader background settings persistence.
- 2026-06-06 11:47:57 CST: Focused UI smoke `MagReaderUITests/testSavedAndReviewTabsShowSeededItems` passed after adding Saved detail sheet checks and Review mastered confirmation coverage.
- 2026-06-06 11:58:40 CST: Full UI smoke `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderUITests test` passed 5/5 tests, including Saved word/sentence detail sheets, Review mastered confirmation, and confirmed deletion after tapping `Delete`.
- 2026-06-06 12:03:42 CST: Strengthened unit coverage passed 14/14 tests. New tests prove the same `CompositeTranslationService` instance switches from Google to MyMemory immediately after `SettingsStore.update`, word dictionary definitions are translated through one batched `translateTexts` call without an extra primary word translation request, and `AVSpeechService.speak` configures `AVAudioSession` with `.playback`.
- 2026-06-06 12:08:26 CST: Final full UI smoke passed 5/5 tests after the provider-switching testability refactor.
- 2026-06-06 12:48:53 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/MagReader/DerivedData build-for-testing` passed outside the sandbox after the single-default-meaning and Review Speak decoupling update.
- 2026-06-06 12:54:09 CST: `xcodebuild -quiet -project ios/MagReader/MagReader.xcodeproj -scheme MagReader -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath ios/MagReader/DerivedData -only-testing:MagReaderTests test` passed 14/14 tests. The provider-switching test now also proves only the first dictionary definition is translated and later definitions remain un-translated until expanded.
- 2026-06-06 13:00:40 CST: Full UI smoke passed 5/5 tests, including `Show More Meanings` in Saved word detail and the existing Review mastered delete flow.
- 2026-06-06 15:19:31 CST: Build iOS Apps `build_sim` passed for `MagReader` on iPhone 17 Simulator after the fast-word-translation/on-demand-dictionary refactor.
- 2026-06-06 15:23:31 CST: Build iOS Apps `test_sim -only-testing:MagReaderTests` passed 14/14 unit tests. The MCP call exceeded its 120 second response window, but the xcodebuild log recorded `TEST EXECUTE SUCCEEDED` and all unit test cases passed.
- 2026-06-06 15:26:18 CST: Build iOS Apps `test_sim -only-testing:MagReaderUITests` passed 5/5 UI smoke tests. The MCP call exceeded its 120 second response window, and Xcode printed a post-success simulator runner launch warning, but the log recorded `TEST EXECUTE SUCCEEDED` and all UI test cases passed.
- 2026-06-06 15:27:39 CST: Final Build iOS Apps `build_sim` passed after updating `plan.md`; no warnings or errors.
- 2026-06-06 15:45:55 CST: Build iOS Apps `build_sim` passed after the immediate-expanded dictionary display adjustment; no warnings or errors.
- 2026-06-06 21:47:00 CST: Web verification passed after iOS parity sync: `npm run typecheck`, `npm test` passed 30/30 tests, `npm run lint`, and `npm run build`. Next build still prints the existing non-fatal custom ESLint config warning about the Next plugin.
- 2026-06-06 21:56:00 CST: Open-source packaging verification passed: `npm run verify` completed typecheck, 30/30 tests, lint, and production build. Build still prints the existing non-fatal Next ESLint plugin warning. Build iOS Apps `build_sim` also passed for the native iOS app with no warnings or errors.

## Open Questions / Risks

- SPM dependency resolution may be blocked by network restrictions. The current implementation already uses local sqlite3 and a minimal `XMLParser` RSS/Atom parser.
- RSS extraction quality varies by publisher. Full-text extraction should be best effort, with RSS summary fallback as normal behavior.
- Google Translate, MyMemory, and `dictionaryapi.dev` are network services and may rate-limit or fail depending on conditions. The app keeps a test-only fixture translation service for UI tests, but user-facing Settings only exposes Google and MyMemory. Initial single-word analysis now avoids the dictionary network dependency; if the on-demand dictionary lookup fails, the app keeps the fast translation result and does not fabricate dictionary meanings.
- Speak is configured with an active iOS playback/spoken-audio session, but actual audible output still depends on Simulator/device audio routing, mute state, and selected voice availability. Manual audio checks are still needed on the target device.
- `WKWebView` tap-to-highlight/tap-to-translate word selection was verified on Simulator with Build iOS Apps and Computer Use. Long-press sentence selection is implemented with custom WebView range logic and native callout disabled; precise text-coordinate automation remains limited because current tooling exposes the reader as one scroll-view element. Real device checks are still useful before distribution because iOS text selection gesture behavior can vary by OS/device.
- The iOS app intentionally does not share the existing web SQLite database. Data import can be planned later if needed.
