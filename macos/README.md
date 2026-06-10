# MagReader macOS

MagReaderMac is a native SwiftUI macOS app. It runs independently from the Web and iOS apps, stores its own local SQLite database, and does not require Node.js or a local server.

## Features

- Desktop `NavigationSplitView` layout with sidebar navigation.
- Articles grouped by feed with collapsible sections, search, expand all, and collapse all.
- Feed management with add, enable/disable, delete, and refresh actions.
- `WKWebView` reader with theme, font size, line height, paragraph gap, and reader background settings.
- Two-step reader interaction:
  - Click a word to highlight it, then click the highlight to translate.
  - Double-click a sentence to highlight it, then click the highlight to translate.
  - Click blank reader space to clear the active highlight.
- Fast word translation first, then `Show More Meanings` loads dictionary meanings on demand.
- Saved words, saved sentences, review, explicit Speak buttons, and mastered confirmation.
- CSV and JSON export through the macOS save panel.
- Settings window for translation provider, typography, reader background, and speech rate.

## Requirements

- macOS
- Xcode 26.x or a compatible recent Xcode
- Network access for RSS, translation, and dictionary lookup

## Open In Xcode

Open:

```bash
open macos/MagReaderMac.xcodeproj
```

In Xcode:

1. Select the `MagReaderMac` scheme.
2. Select `My Mac` as the run destination.
3. Use Product > Build to compile the app.
4. Use Product > Run to launch it locally.

## Project Structure

```text
macos/
├── MagReaderMac.xcodeproj
├── MagReaderMac/        # SwiftUI app, AppKit/WebKit bridges, assets
├── MagReaderMacTests/   # Reserved for macOS-specific tests
└── MagReaderMacUITests/ # Reserved for UI smoke tests
```

Shared models, SQLite, RSS, translation, dictionary, analysis, and export logic live in `shared/MagReaderCore`.

## Data

The app stores its SQLite database at:

```text
~/Library/Application Support/MagReaderMac/magreader-macos.db
```

The macOS app does not read, migrate, or share the Web or iOS databases.

## Verification

Use Xcode:

- Product > Build
- Product > Run

Optional command-line build:

```bash
xcodebuild -project macos/MagReaderMac.xcodeproj -scheme MagReaderMac CODE_SIGNING_ALLOWED=NO build
```

This project intentionally does not include DMG packaging, signing, or notarization in the first macOS source release.
