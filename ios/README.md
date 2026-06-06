# MagReader iOS

The iOS version is a native SwiftUI app. It stores data in the iOS app sandbox and runs as its own Xcode project.

## Features

- Native SwiftUI tab navigation for Articles, Feeds, Saved, Review, and Settings.
- Local SQLite persistence.
- RSS/Atom refresh through `URLSession`.
- Article reader powered by `WKWebView`.
- Tap word to highlight, tap active highlight to translate.
- Long press sentence to highlight, tap active highlight to translate.
- Fast word translation with optional dictionary meanings.
- Saved words/sentences, review, settings, and native speech.

## Requirements

- macOS
- Xcode 26.x or a compatible recent Xcode
- Network access for RSS, translation, and dictionary lookup

## Open In Xcode

Open:

```bash
open ios/MagReader.xcodeproj
```

In Xcode:

1. Select the `MagReader` scheme.
2. Use Xcode's standard device/destination controls for your local setup.
3. Use Product > Build to compile the app.
4. Use Product > Test to run tests when your signing and destination are configured.

## Project Structure

```text
ios/
├── MagReader.xcodeproj
├── MagReader/           # SwiftUI app source
├── MagReaderTests/      # Unit tests
└── MagReaderUITests/    # UI smoke tests
```

## Data

The app stores its SQLite database inside the iOS app sandbox. It does not read or migrate another platform database.

## Verification

Use Xcode:

- Product > Build
- Product > Test
