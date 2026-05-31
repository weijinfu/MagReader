# MagReader Plan

## Current Goal

Implement a local-first English foreign-article reading web app with RSS ingestion, immersive reading, vocabulary/sentence saving, pronunciation, lightweight review, typography controls, dark mode, and mock AI learning tools.

## Completed Work

- 2026-05-24 23:58:20 CST: Confirmed the workspace was empty and selected a clean Next.js + TypeScript implementation.
- 2026-05-24 23:58:20 CST: Locked MVP defaults: local SQLite storage, server-side RSS polling/manual refresh, mock AI/translation providers, browser speech synthesis, immersive annotation, lightweight review.
- 2026-05-24 23:58:20 CST: Generated visual direction for a three-panel reading app: left navigation, center article reader, right learning panel, clean editorial UI, teal accent, dark mode support.
- 2026-05-25 00:06:30 CST: Created Next.js/TypeScript scaffold, package scripts, styling baseline, app shell entrypoints, and installed dependencies.
- 2026-05-25 00:06:30 CST: Added SQLite schema initialization for feeds, articles, saved words, saved sentences, annotations, settings, and ingestion logs.
- 2026-05-25 00:06:30 CST: Added RSS parsing/extraction pipeline with Readability fallback, deduplication by URL, ingestion logs, and 30-minute in-process scheduler.
- 2026-05-25 00:06:30 CST: Added mock AI provider for word/sentence translation, explanation, phrase notes, structure analysis, and difficulty rating.
- 2026-05-25 00:06:30 CST: Added API routes for dashboard, feeds, feed refresh, articles, mock AI, saved words, saved sentences, settings, and export.
- 2026-05-25 00:06:30 CST: Implemented main three-panel UI with article list, reader, selection analysis, pronunciation, saving, review, feed management, settings, dark mode, typography controls, and CSV export.
- 2026-05-25 00:23:10 CST: Completed browser verification with Playwright CLI fallback, including article view, dark mode toggle, review view, settings view, local API checks, save word/sentence, review status updates, and CSV export.
- 2026-05-25 01:14:30 CST: Added collapsible controls for the left navigation and article list so the reader can use a much wider content area.
- 2026-05-25 09:32:19 CST: Optimized article-body selection: single-click selects the full sentence, drag selection still supports words/phrases, and translation/explanation now runs from explicit toolbar or panel actions instead of immediately on selection.
- 2026-05-25 10:27:59 CST: Refined sentence selection state and toolbar behavior: stable highlighted sentences, toolbar status states, Translate/Save completion fade-out, Esc/outside-click dismissal, and clearer division between quick toolbar actions and full Learning Panel details.
- 2026-05-25 11:14:03 CST: Updated reader selection interaction so single-click selects a sentence and double-click selects the current word, with stable React-rendered highlights for both sentence and word selections.
- 2026-05-25 11:32:28 CST: Removed the full article-body HTML rewrite from selection highlighting. Selection now keeps the original article DOM stable and applies/removes a lightweight local highlight mark after render, eliminating the page refresh/flicker feeling during reading.
- 2026-05-25 15:45:10 CST: Improved double-click word selection visibility with a stronger word-specific highlight while keeping the article DOM stable.
- 2026-05-25 15:45:10 CST: Added hard-delete support for saved words and saved sentences through database helpers and `DELETE /api/words?id=...` / `DELETE /api/sentences?id=...`.
- 2026-05-25 15:45:10 CST: Expanded Saved Words and Saved Sentences with status/source filters, sorting controls, detail expansion, speak/status/delete actions, and clearer count/source metadata.
- 2026-05-25 15:45:10 CST: Expanded Review with type/status filters, hidden-answer review cards, reveal/details controls, status progression, speech, and shared delete behavior.
- 2026-05-25 16:34:00 CST: Fixed the remaining double-click word highlight issue. Single-click sentence selection now waits briefly before applying the sentence mark, so a second click can cancel it and select the word. Manual/native word selections also create the same stable word highlight.
- 2026-05-25 18:52:15 CST: Moved the article list visibility control into the top toolbar as `Hide list` / `Show list` and removed the old list-header/body-level toggle buttons.
- 2026-05-25 18:52:15 CST: Added article-body media constraints so RSS images, figures, picture/video/iframe elements, and common image wrapper nodes stay inside the reader content width.
- 2026-05-25 19:03:42 CST: Removed timed disappearance for the selection toolbar and selected-text highlight. Toolbar/highlight now persist after analysis or save until the user explicitly clears selection, changes selection, switches article/page, or presses Esc.
- 2026-05-29 15:34:16 CST: Improved reader highlighting for paragraphs with nested inline nodes by replaying highlights across text-node segments instead of requiring one `Range.surroundContents()` call to cover the whole sentence.
- 2026-05-29 15:34:16 CST: Hid BBC/Readability gray placeholder images such as `grey-placeholder.png` and `aria-label="image unavailable"` while keeping the real article image and caption visible.
- 2026-05-29 15:42:53 CST: Added `figcaption` to reader selectable text blocks and fixed caption selection so image captions can be clicked or manually selected to create the same stable sentence highlight as body paragraphs.

## In Progress

- Done.

## Next Steps

- Replace mock AI/translation providers with real OpenAI or other provider integrations when ready.
- Add OPML import/export for RSS feed lists.
- Add richer spaced repetition scheduling if the lightweight review flow is not enough.
- Add account/cloud sync only if multi-device use becomes a requirement.

## Open Questions / Risks

- Real translation and AI integrations are deferred; mock provider contracts must stay easy to replace.
- RSS article extraction can vary by publisher; MVP needs graceful fallback from full article extraction to feed summaries.
- Browser speech voices differ by operating system and browser.
- Server-side scheduled RSS refresh runs only while the app server process is active.
- The app is implemented as a local-first single-user MVP; multi-user auth/sync is intentionally out of scope.
- Browser verification for destructive delete confirmation is intentionally limited because it permanently removes local saved learning data; delete behavior is covered by database/API implementation and automated tests.

## Verification Status

- 2026-05-25 00:12:20 CST: First verification found issues: `stripHtml` left spaces before punctuation, RSS parser item type missed optional author field, and sandbox blocked `tsx` IPC for db init.
- 2026-05-25 00:13:55 CST: Database initialization, unit tests, and TypeScript checks passed. Production build passed, but standalone lint failed because deprecated `next lint` is incompatible with the current ESLint stack; migrating to ESLint CLI.
- 2026-05-25 00:15:10 CST: Production build passed after ESLint migration. Standalone lint only flagged the framework-generated `next-env.d.ts` triple-slash references; rule disabled for that generated file.
- 2026-05-25 00:16:00 CST: Lint, typecheck, and unit tests passed after fixes. Cleaned duplicate dev dependency entries caused by retrying ESLint package installation.
- 2026-05-25 00:17:05 CST: Final command verification passed: `npm test`, `npm run lint`, `npm run typecheck`, and `npm run build`. Build prints a non-fatal warning that the Next ESLint plugin is not detected because the project uses a custom flat ESLint CLI config.
- 2026-05-25 00:18:00 CST: Browser snapshot loaded the app successfully and confirmed primary UI regions rendered. The only console error was a missing favicon, fixed by adding `app/icon.svg`.
- 2026-05-25 00:20:10 CST: Playwright screenshot exposed a medium-desktop layout bug where the reader became too narrow at 1280px because article list and reader shared the already constrained center column. Added a 1181-1440px breakpoint that stacks the article list above the reader.
- 2026-05-25 00:23:10 CST: Final verification passed: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`, local homepage HTTP 200, dashboard API, mock AI API, save word API, save sentence API, review status PATCH APIs, CSV export, and Playwright snapshots/screenshots. The only remaining build message is a non-fatal Next warning that the custom flat ESLint config does not include the Next plugin.
- 2026-05-25 01:14:30 CST: Collapsible reading layout verification passed. `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed; local page returned HTTP 200; Playwright screenshot saved to `output/playwright/collapsed-reading-layout.png`.
- 2026-05-25 09:32:19 CST: Sentence-selection optimization verification passed. `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed. In-app browser verified: click a reader sentence -> floating toolbar appears -> Learning Panel shows selected sentence without analysis -> toolbar Translate loads Google Translate, explanation, difficulty, phrase notes, and structure. Console had no app errors.
- 2026-05-25 10:27:59 CST: Selection-state toolbar verification passed. `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed. In-app browser verified: sentence click shows stable highlight and Ready toolbar; Translate shows Analyzing then fades out after completion while Learning Panel keeps results; direct Save analyzes/saves then fades out; Esc and outside click clear selection/highlight/toolbar. Console had no app errors.
- 2026-05-25 11:14:03 CST: Click/double-click selection verification passed. `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed. In-app browser verified: clicking a sample sentence highlights the full sentence and updates the panel; double-clicking within that sentence switches to a word highlight (`learners`) and updates the toolbar/panel to the word selection. Console had no app errors.
- 2026-05-25 11:32:28 CST: No-refresh selection verification passed. `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed. In-app browser verified that clicking a sentence and double-clicking a word keep the same scroll position and paragraph count while only swapping the local highlight mark and selection panel state.
- 2026-05-25 15:45:10 CST: Saved/Review management verification passed for command checks: `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build` passed. Added DB tests proving `deleteSavedWord()` and `deleteSavedSentence()` remove items from returned lists.
- 2026-05-25 15:45:10 CST: Browser verification partially passed before the temporary dev server became unreachable: Saved Words showed filter/sort controls, Details buttons, Delete buttons, and expandable source/time metadata; Saved Sentences showed filter/sort controls and Delete buttons. Review filtering UI rendered, but live reveal/delete review flow was not fully exercised because the current local queue had no due non-mastered items.
- 2026-05-25 16:34:00 CST: Double-click word highlight fix passed command verification: `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build`. Browser debugging reproduced the failure mode where the first click's sentence mark prevented reliable double-click word selection; the fix delays sentence marking and preserves word highlights from native selection. The dev server is currently on `http://127.0.0.1:3001` because local port 3000 is occupied by process 76955.
- 2026-05-25 18:52:15 CST: Article list toggle/media overflow verification passed. `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build` passed. Browser verified on `http://127.0.0.1:3001`: top toolbar shows `Hide list`, clicking it hides the article list and changes the button to `Show list`, clicking `Show list` restores the list, old `Collapse`/`Show article list` buttons are gone, dark mode keeps the toolbar readable, and current article media overflow is 0px across 6 media elements.
- 2026-05-25 19:03:42 CST: Persistent selection verification passed. `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build` passed. Browser verified on `http://127.0.0.1:3001`: after selecting a sentence and clicking `Translate`, the toolbar remained visible and the sentence highlight remained present 4.5 seconds after analysis completed.
- 2026-05-29 15:34:16 CST: Highlight/placeholder cleanup verification passed. `npm run lint`, `npm test`, `npm run build`, and a second `npm run typecheck` after build passed; the first `typecheck` only failed because `.next/types` was momentarily missing while build regenerated it. Browser verified on `http://127.0.0.1:3002`: clicking the headline and four body paragraphs each produced one stable sentence highlight, Browser console had no app errors, and visible gray placeholder image count was 0.
- 2026-05-29 15:42:53 CST: Figcaption highlight verification passed. `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build` passed. Browser verified on `http://127.0.0.1:3004`: clicking the caption “About 70 people were evacuated as the fire was put out” produced one stable sentence highlight, selected text matched the caption, toolbar showed Ready actions, and Browser console had no app errors.
- 2026-05-29 16:28:31 CST: Started translation-provider sync pass. Goal: replace the Tencent deployment's unreachable Google public endpoint with a free online provider that is selectable in Settings and shared by local/remote code. Remote checks showed Google public endpoint timed out from `tecent`, while MyMemory free translation returned Chinese successfully.
- 2026-05-29 16:34:24 CST: Translation-provider sync verification passed. Added Settings-selectable providers (`mymemory`, `google`, `youdao`, `mock`), defaulted new installs to MyMemory, kept Youdao official API support behind `YOUDAO_APP_KEY`/`YOUDAO_APP_SECRET`, and deployed the same code to `tecent`. Local checks passed: `npm test`, `npm run typecheck`, `npm run lint`, `npm run build`. Remote checks passed: `npm run build`, `npm run db:init`, `magreader.service` active, `/api/settings` shows `translationProvider: "mymemory"`, and public `/api/ai` returned provider `MyMemory Translate` with Chinese output.
- 2026-05-29 16:52:33 CST: Mobile UI optimization pass completed and deployed to `tecent`. Added mobile bottom tab navigation, compact wrapping top toolbar, reader-first article layout, mobile-visible Learning Panel below the reader, safer selection toolbar placement above the bottom nav, tighter mobile reader/card spacing, and mobile-specific heading/text sizing. Local checks passed: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Browser plugin loaded the app on `http://127.0.0.1:3005/` with no console errors, but could not change the in-app browser viewport; mobile behavior was verified by CSS/media-rule inspection plus command checks. Remote checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, and `/api/ai` still returns `MyMemory Translate`.
- 2026-05-29 16:54:40 CST: Started expanded translation-engine pass. Goal: add Settings options for Baidu, NetEase Youdao, Microsoft, and Google while keeping MyMemory as the no-key default. Implemented Baidu and Microsoft provider wrappers with clear missing-key errors; NetEase maps to the existing Youdao official API implementation.
- 2026-05-29 16:58:56 CST: Expanded translation-engine pass completed and deployed to `tecent`. Settings now offers MyMemory Free, Baidu API, NetEase Youdao API, Microsoft Translator, Google Public, and Mock. Local checks passed: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Remote checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, `/api/settings` preserved `translationProvider: "mymemory"`, and `/api/ai` still returns `MyMemory Translate`.
- 2026-05-29 17:22:43 CST: Mobile white-screen mitigation deployed to `tecent`. Root cause is likely stale mobile browser HTML referencing old Next chunks after repeated deployments; the homepage had been statically prerendered and returned long-lived cache headers. Changed `app/page.tsx` to `dynamic = "force-dynamic"` and `revalidate = 0`. Local checks passed: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`; build now marks `/` as dynamic. Remote checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, and public `http://150.158.141.102/` now returns `Cache-Control: private, no-cache, no-store, max-age=0, must-revalidate`.
- 2026-05-30 22:08:57 CST: Follow-up mobile blank-layout fix deployed to `tecent`. User screenshot showed the old mobile CSS still rendering the sidebar as a full-height top block, likely because iOS cached the immutable Next CSS asset. Added an inline mobile cache-bypass style in `app/layout.tsx` to force the nav to the bottom, keep `.main` visible, and restore the reader/content layout even if an old CSS file is cached. Local checks passed: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Remote checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, no-cache homepage headers, and public HTML contains `position: fixed !important` mobile override rules.
- 2026-05-30 22:37:43 CST: Mobile bottom learning sheet verification passed for command and deployment checks. Local checks passed: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Remote checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, public homepage no-cache headers, public HTML contains the mobile sheet CSS (`mobile-learning-sheet` and fixed-position override), and public `/api/ai` still returns `MyMemory Translate`. Browser-plugin visual mobile verification was limited by navigation timeout on the local dev server, so final phone interaction should be checked directly on `http://150.158.141.102/`.
- 2026-05-31 10:28:49 CST: Local verification passed after icon and drawer fixes: `npm run typecheck`, `npm run lint`, `npm test`, and `npm run build`. Browser verification on `http://127.0.0.1:3005/` confirmed primary nav has six visible icons, toolbar has action icons, horizontal overflow is 0px, article reader is visible, selecting an article paragraph opens the learning drawer at 926px viewport width, Translate keeps the drawer open and shows `MyMemory Translate`, Details expands explanation/difficulty/phrases/structure, the highlight remains stable, and the old selection toolbar is hidden while the drawer is active.
- 2026-05-31 10:35:53 CST: GitHub and tecent sync completed. Committed changes as `4f32281` on `main` and pushed to `origin/main`. Remote deployment checks passed: `npm ci`, `npm run build`, `npm run db:init`, `magreader.service` active, public homepage HTTP 200 with no-cache headers, public HTML contains `nav-icon` and `mobile-learning-sheet`, and public `/api/ai` returns `MyMemory Translate`.
- 2026-05-31 10:42:10 CST: Added regression coverage for settings persistence, duplicate saved-word count updates, review familiarity transitions, and persisted mock translation-provider behavior. Local verification passed: `npm run typecheck`, `npm run lint`, `npm test` (19 tests), and `npm run build`.
- 2026-05-31 11:08:06 CST: Synced the expanded regression tests to tecent and verified the remote test suite in `/home/ubuntu/apps/MagReader`: `npm test` passed with 19 tests.

## Feature Checklist

- [x] Project scaffold
- [x] App shell and navigation
- [x] Collapsible left navigation and article list
- [x] Dark mode
- [x] Typography controls
- [x] SQLite schema
- [x] RSS feed CRUD
- [x] Manual RSS refresh
- [x] Scheduled RSS refresh
- [x] Article extraction and deduplication
- [x] Article list filters/search
- [x] Reader page
- [x] Click-to-select sentence flow
- [x] Double-click-to-select word flow
- [x] Stable selected word highlight
- [x] Floating selection toolbar
- [x] Deferred translation/explanation trigger
- [x] Stable selected sentence highlight
- [x] Selection toolbar status and fade-out rules
- [x] Text selection annotation panel
- [x] Word translation/explanation mock
- [x] Sentence translation/explanation mock
- [x] Selectable translation provider setting
- [x] MyMemory free online translation provider
- [x] Baidu translation provider option
- [x] NetEase Youdao translation provider option
- [x] Microsoft Translator provider option
- [x] Optional Youdao official API translation provider
- [x] Mobile bottom navigation
- [x] Mobile reader-first layout
- [x] Mobile Learning Panel access
- [x] Mobile bottom learning sheet
- [x] Mobile compact translation results
- [x] Mobile expandable learning details
- [x] Mobile selection toolbar placement
- [x] Menu icons for primary navigation
- [x] Toolbar icons for common actions
- [x] Tablet/narrow-desktop learning drawer fallback
- [x] Long-sentence analysis mock
- [x] Phrase explanation mock
- [x] Difficulty rating mock
- [x] Browser pronunciation
- [x] Save words
- [x] Save original sentences
- [x] Saved item search/filter
- [x] Saved Words filters/sorting/details
- [x] Saved Sentences filters/sorting/details
- [x] Saved word/sentence hard delete APIs
- [x] Lightweight review queue
- [x] Review type/status filters
- [x] Review hidden-answer card flow
- [x] CSV/JSON export
- [x] Lint/typecheck/build verification

## Progress Notes

- 2026-05-24 23:58:20 CST: Started implementation from an empty workspace.
- 2026-05-25 00:06:30 CST: Feature implementation pass complete; moving into verification.
- 2026-05-25 00:12:20 CST: Fixed text cleanup and RSS item typing; db init will be rerun with escalation because sandbox denied tsx IPC pipe creation.
- 2026-05-25 00:13:55 CST: Replaced deprecated `next lint` script with ESLint CLI flat config.
- 2026-05-25 00:17:05 CST: Starting local browser verification after passing command checks.
- 2026-05-25 00:20:10 CST: Fixing browser-discovered responsive layout issue before final verification.
- 2026-05-25 00:23:10 CST: Local dev server is running at http://localhost:3000 for manual testing.
- 2026-05-25 00:30:00 CST: User reported the app could not open. Reproduced startup failure: Next tried to listen on `0.0.0.0:3000` and the environment returned `EPERM`. Updated `dev` and `start` scripts to bind `127.0.0.1` explicitly.
- 2026-05-25 00:31:00 CST: Verified startup succeeds when local port listening is allowed. App responds at `http://127.0.0.1:3000` with HTTP 200 and `/api/dashboard` returns local data successfully.
- 2026-05-25 00:45:00 CST: Replaced UI/API translation output with Google Translate-backed server translation while keeping AI explanation/phrase/difficulty analysis as local mock logic.
- 2026-05-25 00:45:00 CST: Used BBC World RSS (`https://feeds.bbci.co.uk/news/world/rss.xml`) as a real online RSS source. Added it through the Feeds UI and refreshed it; 43 BBC articles were stored.
- 2026-05-25 00:45:00 CST: Browser-tested a BBC article sentence: selected “Turkish riot police forced their way into the headquarters of the country's main opposition party on Sunday, days after a court dismissed its leadership.” The learning panel showed provider “Google Translate” and Chinese translation “土耳其防暴警察周日强行闯入该国主要反对党的总部，几天前，法院驳回了该党的领导层职务。”
- 2026-05-25 00:45:00 CST: Saved that translated BBC sentence and verified it in SQLite with article id 6. Selected and saved the BBC article word `barricade`; Google Translate returned “路障”, and SQLite shows `saved_words` row id 2 for article id 6.
- 2026-05-25 00:45:00 CST: Final verification passed after Google Translate changes: `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build`. Browser screenshot saved to `output/playwright/bbc-google-translate-save-test.png`.
- 2026-05-25 01:12:00 CST: User reported the article body占比 was too small. Added collapsible controls for both left-side regions: the global navigation collapses into a narrow rail, and the article list can be hidden with a restore button above the reader. When the article list is hidden, the reader uses a wider layout.
- 2026-05-25 01:14:30 CST: Verified the collapsed layout in browser: the left navigation rail is narrow, the article list is hidden behind a restore button, and the article body expands across the main reading area. Screenshot: `output/playwright/collapsed-reading-layout.png`.
- 2026-05-25 09:32:19 CST: Implemented the planned正文句子选中优化. Added `sentenceAtOffset()` with abbreviation/decimal handling, upgraded `sentenceAround()`, added tests for sentence boundaries, and changed the reader to select full sentences on click while deferring AI calls until the user chooses Translate/Explain/Save.
- 2026-05-25 10:27:59 CST: Implemented the planned follow-up for选中状态 and悬浮窗/右侧面板分工. The toolbar now acts as a compact quick-action surface with Ready/Analyzing/Analyzed/Saved/Failed feedback, fades out after successful Translate or Save, and leaves full analysis/save state in the Learning Panel.
- 2026-05-25 11:14:03 CST: Implemented “点击选句子，双击选单词”. Added `wordAtOffset()` tests for plain, apostrophe, and hyphenated words; the reader now handles `onDoubleClick` by selecting the word at the pointer and rendering a word-specific highlight.
- 2026-05-25 11:32:28 CST: Fixed selection flicker by replacing React-generated highlighted article HTML with an imperative local highlight effect scoped to `.article-body`. This prevents the full article content from being replaced on every sentence click.
- 2026-05-25 15:45:10 CST: Implemented the planned single-word selection display and Saved/Review management pass. Word selection now has a stronger dedicated highlight, saved words/sentences can be filtered/sorted/expanded/deleted, and Review now has type/status filters with hidden-answer cards.
- 2026-05-25 15:45:10 CST: Final command verification passed for this pass: `npm test`, `npm run typecheck`, `npm run lint`, and `npm run build`. Browser validation covered Saved Words/Sentences management UI partially; destructive delete and full Review reveal/delete were left to non-destructive manual confirmation because current local data had no active review queue item and delete is permanent.
- 2026-05-25 16:34:00 CST: Reworked the reader click timing so single-click sentence selection no longer mutates the article DOM before a possible double-click arrives. Added stable word highlight creation for native word selections and made failed caret calculations preserve any existing highlight instead of clearing it.
- 2026-05-25 18:52:15 CST: Implemented the article list toggle placement and image overflow plan. The list visibility button now lives in the top toolbar, and article media is constrained to the reader card without cropping.
- 2026-05-25 19:03:42 CST: Removed the toolbar auto-hide timer and the hover state that only existed to pause that timer. Also made the reader re-apply the active highlight after every render so analysis/save state updates do not wipe the selected sentence mark.
- 2026-05-29 15:34:16 CST: Fixed highlight replay for complex article DOM structures and removed redundant BBC gray image placeholders. Local verification server is on `http://127.0.0.1:3002` because port 3000 is occupied by another local process.
- 2026-05-29 15:42:53 CST: Fixed the user-reported caption that could not be clicked/highlighted. Local verification server is on `http://127.0.0.1:3004` because port 3000 is occupied by another local process.
- 2026-05-30 22:37:43 CST: Implemented the mobile reading/translation bottom sheet and deployed it to `tecent`. On mobile, selected text now opens a bottom drawer above the nav; Translate shows loading and compact results in the drawer without scrolling to the bottom of the page; Details expands explanation, difficulty, phrases, and structure. Desktop keeps the right-side Learning Panel unchanged.
- 2026-05-31 10:28:49 CST: Continued UI optimization toward the cross-device polish goal. Added inline SVG icons to primary navigation and top toolbar actions, changed mobile navigation to icon + short labels to avoid truncation, fixed the 820-1180px layout where the right Learning Panel was hidden but no learning drawer was visible, and prevented clicks inside the learning drawer from clearing the active selection.
- 2026-05-31 10:35:53 CST: Synced the current optimized build to GitHub and tecent. Public URL verification passed for no-cache headers, deployed icon/mobile-sheet styles, active service, and translation API health.
- 2026-05-31 10:42:10 CST: Strengthened functional test coverage around persistence and learning workflow state. Added tests for reader settings, saved-word repeat count behavior, word/sentence review status updates, and mock translation provider selection.
- 2026-05-31 11:08:06 CST: Verified the new regression suite on tecent after syncing the test files; remote `npm test` now passes 19 tests.
