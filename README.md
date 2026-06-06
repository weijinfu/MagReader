# MagReader

MagReader is a local-first RSS reader built for language learners. It helps you read English articles, select words or sentences, translate them, save useful material, and review it later.

The project currently ships two platform versions:

- **Web**: a Next.js app with local SQLite storage.
- **iOS**: a native SwiftUI app under `ios/MagReader`, also backed by local SQLite in the app sandbox.

The Web and iOS apps are intentionally independent. They do not share a database or require a hosted backend.

## Highlights

- RSS/Atom feed management and refresh.
- Article reading with typography controls.
- Articles grouped by Feed with collapsible sections.
- Two-step reader selection:
  - click/tap a word to highlight it;
  - click/tap the active highlight to translate;
  - long press a sentence to highlight it;
  - click/tap the active sentence highlight to translate.
- Fast word translation first, then optional `Show More Meanings` dictionary lookup.
- Dictionary-style word meanings from `dictionaryapi.dev`, translated to Chinese through the selected provider.
- Saved words and saved sentences with local review state.
- Review queue with explicit Speak and mastered confirmation.
- Google Translate public endpoint and MyMemory as user-visible providers.
- CSV/JSON export in the Web app.

## Repository Layout

```text
.
├── app/                         # Next.js App Router pages and API routes
├── components/                  # Web UI components
├── lib/                         # Web data, RSS, translation, dictionary, and utility logic
├── scripts/                     # Local maintenance scripts
├── tests/                       # Web unit and UI smoke tests
├── ios/MagReader/               # Native SwiftUI iOS app and Xcode project
├── docs/                        # Architecture, platform, and comparison docs
├── plan.md                      # Long-running implementation log and next steps
└── README.md
```

## Platform Status

| Platform | Status | Entry Point |
| --- | --- | --- |
| Web | Active | `npm run dev` |
| iOS | Active | `ios/MagReader/MagReader.xcodeproj` |
| macOS/Android/Desktop | Not implemented | Planned only if there is real demand |

See [docs/platforms.md](docs/platforms.md) for platform-specific notes and [docs/ios-web-feature-comparison.md](docs/ios-web-feature-comparison.md) for current parity details.

## Requirements

### Web

- Node.js 20+
- npm
- Network access for RSS refresh and online translation/dictionary lookup

### iOS

- macOS with Xcode 26.x or compatible recent Xcode
- iOS Simulator or a physical iOS device
- Network access for RSS refresh and online translation/dictionary lookup

## Web Quick Start

```bash
npm install
npm run db:init
npm run dev
```

Default URL:

```text
http://127.0.0.1:3000
```

If port `3000` is occupied, Next.js may choose another local port.

The Web database defaults to:

```text
data/magreader.db
```

To use another SQLite file:

```bash
MAGREADER_DB=/absolute/path/magreader.db npm run dev
```

## iOS Quick Start

Open the project in Xcode:

```bash
open ios/MagReader/MagReader.xcodeproj
```

Select the `MagReader` scheme and run it on an iOS Simulator.

Command-line build:

```bash
npm run ios:build
```

Command-line tests require an available simulator named `iPhone 17` unless you edit the script:

```bash
npm run ios:test
```

## Translation And Dictionary

User-visible providers:

- `google`
- `mymemory`

The app performs a fast translation first. For single words, dictionary meanings are loaded only when the user chooses `Show More Meanings`.

Dictionary source:

- `https://api.dictionaryapi.dev`

Legacy or unknown provider values such as `mock` fall back to Google in user-facing settings. Mock/fixture translation remains test-only.

## Common Commands

```bash
npm run dev          # Start Web dev server
npm run build        # Build Web app
npm run start        # Start built Web app
npm run lint         # ESLint
npm run typecheck    # TypeScript check
npm test             # Vitest
npm run verify       # typecheck + tests + lint + build
npm run db:init      # Initialize local Web SQLite database
npm run ios:build    # Build iOS app for generic iOS Simulator
npm run ios:test     # Run iOS tests on an iPhone 17 simulator
```

## Data And Privacy

- Web data is stored in local SQLite under `data/` by default.
- iOS data is stored in the app sandbox.
- RSS, translation, and dictionary requests go directly to the configured online services.
- There is no account system or cloud sync.

## Documentation

- [docs/architecture.md](docs/architecture.md)
- [docs/platforms.md](docs/platforms.md)
- [docs/development.md](docs/development.md)
- [docs/ios-web-feature-comparison.md](docs/ios-web-feature-comparison.md)
- [plan.md](plan.md)

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes.

For security concerns, see [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
